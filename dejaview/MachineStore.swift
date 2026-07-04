import Foundation
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

    private let defaultsKey = "savedMachines"

    init() {
        load()
    }

    func add(_ machine: SavedMachine, password: String) {
        machines.append(machine)
        persist()
        Keychain.setPassword(password, for: machine.id)
    }

    func update(_ machine: SavedMachine, password: String) {
        guard let index = machines.firstIndex(where: { $0.id == machine.id }) else { return }

        machines[index] = machine
        persist()
        Keychain.setPassword(password, for: machine.id)
    }

    func delete(_ machine: SavedMachine) {
        machines.removeAll { $0.id == machine.id }
        persist()
        Keychain.deletePassword(for: machine.id)
    }

    func contains(_ machine: SavedMachine) -> Bool {
        machines.contains { $0.id == machine.id }
    }

    func password(for machine: SavedMachine) -> String {
        Keychain.password(for: machine.id) ?? ""
    }

    // MARK: - Persistence

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([SavedMachine].self, from: data) else {
            return
        }

        machines = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(machines) else { return }

        UserDefaults.standard.set(data, forKey: defaultsKey)
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

        SecItemAdd(query as CFDictionary, nil)
    }

    static func password(for id: UUID) -> String? {
        var query = baseQuery(for: id)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?

        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    static func deletePassword(for id: UUID) {
        SecItemDelete(baseQuery(for: id) as CFDictionary)
    }
}
