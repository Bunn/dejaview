import Foundation

/// A saved connection. Metadata lives in app storage; the password is stored
/// separately, keyed by the machine's id.
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
