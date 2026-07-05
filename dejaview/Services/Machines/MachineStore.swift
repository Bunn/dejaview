import Foundation
import OSLog

/// Persists saved machines and their Keychain-backed passwords.
final class MachineStore: ObservableObject, MachineStoring {
    @Published private(set) var machines: [SavedMachine] = []

    private let repository: SavedMachineRepository

    init(repository: SavedMachineRepository = UserDefaultsSavedMachineRepository.shared) {
        self.repository = repository
        machines = repository.loadMachines()
    }

    func reload() {
        machines = repository.loadMachines()
    }

    func add(_ machine: SavedMachine, password: String) {
        AppLog.storage.info("Adding saved machine '\(machine.displayName, privacy: .public)' at \(machine.host, privacy: .public):\(machine.port, privacy: .public)")
        machines.append(machine)
        persist()
        repository.setPassword(password, for: machine.id)
    }

    func update(_ machine: SavedMachine, password: String) {
        guard let index = machines.firstIndex(where: { $0.id == machine.id }) else {
            AppLog.storage.warning("Attempted to update missing machine id=\(machine.id.uuidString, privacy: .public)")
            return
        }

        AppLog.storage.info("Updating saved machine '\(machine.displayName, privacy: .public)' at \(machine.host, privacy: .public):\(machine.port, privacy: .public)")
        machines[index] = machine
        persist()
        repository.setPassword(password, for: machine.id)
    }

    func delete(_ machine: SavedMachine) {
        AppLog.storage.info("Deleting saved machine '\(machine.displayName, privacy: .public)'")
        machines.removeAll { $0.id == machine.id }
        persist()
        repository.deletePassword(for: machine.id)
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

    // MARK: - Persistence

    static func savedMachines(repository: SavedMachineRepository = UserDefaultsSavedMachineRepository.shared) -> [SavedMachine] {
        repository.loadMachines()
    }

    private func persist() {
        repository.saveMachines(machines)
    }
}
