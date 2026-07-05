import Foundation

struct ConnectionHistoryEntry: Identifiable, Equatable {
    var id = UUID()
    var machineID: UUID?
    var displayName: String
    var host: String
    var port: UInt16 = 5900
    var username: String
    var connectedAt: Date = .now

    var subtitle: String {
        let hostPort = "\(host):\(String(port))"
        return username.isEmpty ? hostPort : "\(username)@\(hostPort)"
    }
}
