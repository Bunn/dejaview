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
    var endedAt: Date?
    var outcomeRawValue: String = ConnectionHistoryOutcome.completed.rawValue

    init(id: UUID = UUID(),
         machineID: UUID? = nil,
         displayName: String = "",
         host: String = "",
         port: Int = 5900,
         username: String = "",
         connectedAt: Date = .now,
         endedAt: Date? = nil,
         outcomeRawValue: String = ConnectionHistoryOutcome.completed.rawValue) {
        self.id = id
        self.machineID = machineID
        self.displayName = displayName
        self.host = host
        self.port = port
        self.username = username
        self.connectedAt = connectedAt
        self.endedAt = endedAt
        self.outcomeRawValue = outcomeRawValue
    }

    convenience init(id: UUID,
                     machine: SavedMachine,
                     machineID: UUID?,
                     connectedAt: Date,
                     endedAt: Date? = nil,
                     outcome: ConnectionHistoryOutcome = .completed) {
        self.init(id: id,
                  machineID: machineID,
                  displayName: machine.displayName,
                  host: machine.host,
                  port: Int(machine.port),
                  username: machine.username,
                  connectedAt: connectedAt,
                  endedAt: endedAt,
                  outcomeRawValue: outcome.rawValue)
    }

    func finish(at endedAt: Date, outcome: ConnectionHistoryOutcome) {
        self.endedAt = endedAt
        outcomeRawValue = outcome.rawValue
    }

    var entry: ConnectionHistoryEntry {
        ConnectionHistoryEntry(id: id,
                               machineID: machineID,
                               displayName: displayName,
                               host: host,
                               port: UInt16(clamping: port),
                               username: username,
                               connectedAt: connectedAt,
                               endedAt: endedAt,
                               outcome: ConnectionHistoryOutcome(rawValue: outcomeRawValue) ?? .completed)
    }
}
