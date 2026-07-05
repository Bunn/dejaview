import Foundation
import OSLog

/// Persists saved machines and their Keychain-backed passwords.
@MainActor
final class MachineStore: ObservableObject, MachineStoring {
    @Published private(set) var machines: [SavedMachine] = []
    @Published private(set) var recentConnections: [ConnectionHistoryEntry] = []

    private let repository: SavedMachineRepository
    private let recentConnectionLimit = 50

    init(repository: SavedMachineRepository = SwiftDataSavedMachineRepository.shared) {
        self.repository = repository
        reload()
    }

    func reload() {
        machines = repository.loadMachines()
        recentConnections = repository.loadRecentConnections(limit: recentConnectionLimit)
    }

    func add(_ machine: SavedMachine, password: String) {
        AppLog.storage.info("Adding saved machine '\(machine.displayName, privacy: .public)' at \(machine.host, privacy: .public):\(machine.port, privacy: .public)")
        repository.addMachine(machine)
        repository.setPassword(password, for: machine.id)
        reload()
    }

    func update(_ machine: SavedMachine, password: String) {
        guard contains(machine) else {
            AppLog.storage.warning("Attempted to update missing machine id=\(machine.id.uuidString, privacy: .public)")
            return
        }

        AppLog.storage.info("Updating saved machine '\(machine.displayName, privacy: .public)' at \(machine.host, privacy: .public):\(machine.port, privacy: .public)")
        repository.updateMachine(machine)
        repository.setPassword(password, for: machine.id)
        reload()
    }

    func delete(_ machine: SavedMachine) {
        AppLog.storage.info("Deleting saved machine '\(machine.displayName, privacy: .public)'")
        repository.deleteMachine(withID: machine.id)
        repository.deletePassword(for: machine.id)
        reload()
    }

    func contains(_ machine: SavedMachine) -> Bool {
        machines.contains { $0.id == machine.id }
    }

    func machine(withID id: UUID) -> SavedMachine? {
        machines.first { $0.id == id }
    }

    func password(for machine: SavedMachine) -> String {
        guard let password = repository.password(for: machine.id) else {
            AppLog.storage.debug("No Keychain password found for '\(machine.displayName, privacy: .public)'")
            return ""
        }

        return password
    }

    func recordConnection(to machine: SavedMachine) {
        repository.recordConnection(to: machine, at: .now)
        reload()
    }

    // MARK: - Persistence

    static func savedMachines(repository: SavedMachineRepository = SwiftDataSavedMachineRepository.shared) -> [SavedMachine] {
        repository.loadMachines()
    }
}
