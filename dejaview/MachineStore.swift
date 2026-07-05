import Foundation
import OSLog
import Security

/// A saved connection. Metadata lives in UserDefaults; the password is
/// stored separately in the Keychain, keyed by the machine's id.
struct SavedMachine: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var host: String
    var port: UInt16 = 5900
    var username: String

    var displayName: String {
        name.isEmpty ? host : name
    }

    var subtitle: String {
        let hostPort = "\(host):\(String(port))"
        return username.isEmpty ? hostPort : "\(username)@\(hostPort)"
    }
}

/// Persists saved machines and their Keychain-backed passwords.
final class MachineStore: ObservableObject {
    @Published private(set) var machines: [SavedMachine] = []

    private static let defaultsKey = "savedMachines"

    init() {
        machines = Self.savedMachines()
    }

    func reload() {
        machines = Self.savedMachines()
    }

    func add(_ machine: SavedMachine, password: String) {
        AppLog.storage.info("Adding saved machine '\(machine.displayName, privacy: .public)' at \(machine.host, privacy: .public):\(machine.port, privacy: .public)")
        machines.append(machine)
        persist()
        Keychain.setPassword(password, for: machine.id)
    }

    func update(_ machine: SavedMachine, password: String) {
        guard let index = machines.firstIndex(where: { $0.id == machine.id }) else {
            AppLog.storage.warning("Attempted to update missing machine id=\(machine.id.uuidString, privacy: .public)")
            return
        }

        AppLog.storage.info("Updating saved machine '\(machine.displayName, privacy: .public)' at \(machine.host, privacy: .public):\(machine.port, privacy: .public)")
        machines[index] = machine
        persist()
        Keychain.setPassword(password, for: machine.id)
    }

    func delete(_ machine: SavedMachine) {
        AppLog.storage.info("Deleting saved machine '\(machine.displayName, privacy: .public)'")
        machines.removeAll { $0.id == machine.id }
        persist()
        Keychain.deletePassword(for: machine.id)
    }

    func contains(_ machine: SavedMachine) -> Bool {
        machines.contains { $0.id == machine.id }
    }

    func machine(withID id: UUID) -> SavedMachine? {
        machines.first { $0.id == id }
    }

    func password(for machine: SavedMachine) -> String {
        guard let password = Keychain.password(for: machine.id) else {
            AppLog.storage.debug("No Keychain password found for '\(machine.displayName, privacy: .public)'")
            return ""
        }

        return password
    }

    // MARK: - Persistence

    static func savedMachines() -> [SavedMachine] {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else {
            AppLog.storage.info("No saved machines found in UserDefaults")
            return []
        }

        do {
            let machines = try JSONDecoder().decode([SavedMachine].self, from: data)
            AppLog.storage.info("Loaded \(machines.count, privacy: .public) saved machines")
            return machines
        } catch {
            AppLog.storage.error("Failed to decode saved machines: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(machines)
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
            AppLog.storage.debug("Persisted \(self.machines.count, privacy: .public) saved machines")
        } catch {
            AppLog.storage.error("Failed to encode saved machines: \(error.localizedDescription, privacy: .public)")
        }
    }
}

// MARK: - Keychain

private enum Keychain {
    private static let service = "com.example.dejaview.passwords"

    private static func baseQuery(for id: UUID) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: id.uuidString]
    }

    static func setPassword(_ password: String, for id: UUID) {
        var query = baseQuery(for: id)
        SecItemDelete(query as CFDictionary)

        query[kSecValueData as String] = Data(password.utf8)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecSuccess {
            AppLog.storage.debug("Stored Keychain password for id=\(id.uuidString, privacy: .public)")
        } else {
            AppLog.storage.error("Failed to store Keychain password for id=\(id.uuidString, privacy: .public); status=\(status, privacy: .public)")
        }
    }

    static func password(for id: UUID) -> String? {
        var query = baseQuery(for: id)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?

        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data else {
            if status != errSecItemNotFound {
                AppLog.storage.error("Failed to read Keychain password for id=\(id.uuidString, privacy: .public); status=\(status, privacy: .public)")
            }

            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    static func deletePassword(for id: UUID) {
        let status = SecItemDelete(baseQuery(for: id) as CFDictionary)

        if status == errSecSuccess || status == errSecItemNotFound {
            AppLog.storage.debug("Deleted Keychain password for id=\(id.uuidString, privacy: .public); status=\(status, privacy: .public)")
        } else {
            AppLog.storage.error("Failed to delete Keychain password for id=\(id.uuidString, privacy: .public); status=\(status, privacy: .public)")
        }
    }
}
