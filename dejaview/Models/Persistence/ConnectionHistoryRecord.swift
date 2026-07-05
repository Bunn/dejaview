import Foundation
import SwiftData

@Model
final class ConnectionHistoryRecord {
    var id: UUID = UUID()
    var machineID: UUID?
    var displayName: String = ""
    var host: String = ""
    var port: Int = 5900
    var username: String = ""
    var connectedAt: Date = Date.now

    init(id: UUID = UUID(),
         machineID: UUID? = nil,
         displayName: String = "",
         host: String = "",
         port: Int = 5900,
         username: String = "",
         connectedAt: Date = .now) {
        self.id = id
        self.machineID = machineID
        self.displayName = displayName
        self.host = host
        self.port = port
        self.username = username
        self.connectedAt = connectedAt
    }

    convenience init(machine: SavedMachine, machineID: UUID?, connectedAt: Date = .now) {
        self.init(machineID: machineID,
                  displayName: machine.displayName,
                  host: machine.host,
                  port: Int(machine.port),
                  username: machine.username,
                  connectedAt: connectedAt)
    }

    var entry: ConnectionHistoryEntry {
        ConnectionHistoryEntry(id: id,
                               machineID: machineID,
                               displayName: displayName,
                               host: host,
                               port: UInt16(clamping: port),
                               username: username,
                               connectedAt: connectedAt)
    }
}
