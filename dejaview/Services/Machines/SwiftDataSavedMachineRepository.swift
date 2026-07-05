import Foundation
import SwiftData

final class SwiftDataSavedMachineRepository: SavedMachineRepository {
    static let shared = SwiftDataSavedMachineRepository()

    private let modelContainer: ModelContainer
    private let legacyRepository: UserDefaultsSavedMachineRepository
    private let migrationLock = NSLock()
    private let migrationCompletedKey = "savedMachinesSwiftDataMigrationCompleted"
    private let maximumHistoryCount = 100

    init(modelContainer: ModelContainer = DejaViewModelContainer.shared,
         legacyRepository: UserDefaultsSavedMachineRepository = .shared) {
        self.modelContainer = modelContainer
        self.legacyRepository = legacyRepository
    }

    func loadMachines() -> [SavedMachine] {
        performLegacyMigrationIfNeeded()

        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<SavedMachineRecord>(
            sortBy: [
                SortDescriptor(\SavedMachineRecord.sortOrder),
                SortDescriptor(\SavedMachineRecord.createdAt),
                SortDescriptor(\SavedMachineRecord.name)
            ]
        )

        do {
            let records = try context.fetch(descriptor)
            AppLog.storage.info("Loaded \(records.count, privacy: .public) saved machines from SwiftData")
            return records.map(\.savedMachine)
        } catch {
            AppLog.storage.error("Failed to fetch saved machines from SwiftData: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    func addMachine(_ machine: SavedMachine) {
        performLegacyMigrationIfNeeded()

        let context = ModelContext(modelContainer)
        let nextSortOrder = nextSortOrder(in: context)
        let record = SavedMachineRecord(machine: machine, sortOrder: nextSortOrder)
        context.insert(record)
        save(context)
    }

    func updateMachine(_ machine: SavedMachine) {
        performLegacyMigrationIfNeeded()

        let context = ModelContext(modelContainer)

        if let record = machineRecord(withID: machine.id, in: context) {
            record.update(from: machine)
        } else {
            AppLog.storage.warning("SwiftData record missing for update; inserting machine id=\(machine.id.uuidString, privacy: .public)")
            context.insert(SavedMachineRecord(machine: machine, sortOrder: nextSortOrder(in: context)))
        }

        save(context)
    }

    func deleteMachine(withID id: UUID) {
        performLegacyMigrationIfNeeded()

        let context = ModelContext(modelContainer)

        guard let record = machineRecord(withID: id, in: context) else {
            AppLog.storage.warning("Attempted to delete missing SwiftData machine id=\(id.uuidString, privacy: .public)")
            return
        }

        context.delete(record)
        save(context)
    }

    func loadRecentConnections(limit: Int) -> [ConnectionHistoryEntry] {
        performLegacyMigrationIfNeeded()

        let context = ModelContext(modelContainer)
        var descriptor = FetchDescriptor<ConnectionHistoryRecord>(
            sortBy: [SortDescriptor(\ConnectionHistoryRecord.connectedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit

        do {
            return try context.fetch(descriptor).map(\.entry)
        } catch {
            AppLog.storage.error("Failed to fetch connection history from SwiftData: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    func recordConnection(to machine: SavedMachine, at date: Date) {
        performLegacyMigrationIfNeeded()

        let context = ModelContext(modelContainer)
        let savedRecord = machineRecord(withID: machine.id, in: context)

        savedRecord?.lastConnectedAt = date
        savedRecord?.updatedAt = date

        context.insert(ConnectionHistoryRecord(machine: machine,
                                               machineID: savedRecord?.id,
                                               connectedAt: date))
        pruneConnectionHistory(in: context)
        save(context)
    }

    func password(for id: UUID) -> String? {
        performLegacyMigrationIfNeeded()

        let context = ModelContext(modelContainer)

        guard let record = machineRecord(withID: id, in: context) else {
            return legacyRepository.password(for: id)
        }

        if let password = record.password {
            return password
        }

        guard let legacyPassword = legacyRepository.password(for: id) else {
            return nil
        }

        record.password = legacyPassword
        record.updatedAt = .now
        save(context)

        return legacyPassword
    }

    func setPassword(_ password: String, for id: UUID) {
        performLegacyMigrationIfNeeded()

        let context = ModelContext(modelContainer)

        guard let record = machineRecord(withID: id, in: context) else {
            AppLog.storage.warning("Attempted to set password for missing SwiftData machine id=\(id.uuidString, privacy: .public)")
            legacyRepository.setPassword(password, for: id)
            return
        }

        record.password = password
        record.updatedAt = .now
        save(context)
        legacyRepository.setPassword(password, for: id)
    }

    func deletePassword(for id: UUID) {
        performLegacyMigrationIfNeeded()

        let context = ModelContext(modelContainer)

        if let record = machineRecord(withID: id, in: context) {
            record.password = nil
            record.updatedAt = .now
            save(context)
        }

        legacyRepository.deletePassword(for: id)
    }

    private func performLegacyMigrationIfNeeded() {
        migrationLock.lock()
        defer { migrationLock.unlock() }

        let defaults = UserDefaults.standard

        guard !defaults.bool(forKey: migrationCompletedKey) else { return }

        let legacyMachines = legacyRepository.loadMachines()

        guard !legacyMachines.isEmpty else {
            defaults.set(true, forKey: migrationCompletedKey)
            return
        }

        let context = ModelContext(modelContainer)
        var insertedCount = 0

        for (index, machine) in legacyMachines.enumerated() where machineRecord(withID: machine.id, in: context) == nil {
            let legacyPassword = legacyRepository.password(for: machine.id)
            context.insert(SavedMachineRecord(machine: machine,
                                              password: legacyPassword,
                                              sortOrder: index))
            insertedCount += 1
        }

        do {
            try context.save()
            defaults.set(true, forKey: migrationCompletedKey)
            AppLog.storage.info("Migrated \(insertedCount, privacy: .public) saved machines from UserDefaults to SwiftData")
        } catch {
            AppLog.storage.error("Failed to migrate saved machines to SwiftData: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func machineRecord(withID id: UUID, in context: ModelContext) -> SavedMachineRecord? {
        var descriptor = FetchDescriptor<SavedMachineRecord>(
            predicate: #Predicate<SavedMachineRecord> { record in
                record.id == id
            }
        )
        descriptor.fetchLimit = 1

        do {
            return try context.fetch(descriptor).first
        } catch {
            AppLog.storage.error("Failed to fetch saved machine id=\(id.uuidString, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func nextSortOrder(in context: ModelContext) -> Int {
        var descriptor = FetchDescriptor<SavedMachineRecord>(
            sortBy: [SortDescriptor(\SavedMachineRecord.sortOrder, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        do {
            return (try context.fetch(descriptor).first?.sortOrder ?? -1) + 1
        } catch {
            AppLog.storage.error("Failed to compute next machine sort order: \(error.localizedDescription, privacy: .public)")
            return 0
        }
    }

    private func pruneConnectionHistory(in context: ModelContext) {
        var descriptor = FetchDescriptor<ConnectionHistoryRecord>(
            sortBy: [SortDescriptor(\ConnectionHistoryRecord.connectedAt, order: .reverse)]
        )
        descriptor.fetchOffset = maximumHistoryCount

        do {
            let staleRecords = try context.fetch(descriptor)
            staleRecords.forEach(context.delete)
        } catch {
            AppLog.storage.error("Failed to prune connection history: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func save(_ context: ModelContext) {
        do {
            try context.save()
        } catch {
            AppLog.storage.error("Failed to save SwiftData changes: \(error.localizedDescription, privacy: .public)")
        }
    }
}
