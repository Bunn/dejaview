import Foundation
import SwiftData

@Model
final class SavedMachineRecord {
    var id: UUID = UUID()
    var name: String = ""
    var host: String = ""
    var port: Int = 5900
    var username: String = ""
    @Attribute(.allowsCloudEncryption) var password: String?
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var lastConnectedAt: Date?
    var sessionPreferencesData: Data?
    var sortOrder: Int = 0

    init(id: UUID = UUID(),
         name: String = "",
         host: String = "",
         port: Int = 5900,
         username: String = "",
         password: String? = nil,
         createdAt: Date = .now,
         updatedAt: Date = .now,
         lastConnectedAt: Date? = nil,
         sessionPreferencesData: Data? = nil,
         sortOrder: Int = 0) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastConnectedAt = lastConnectedAt
        self.sessionPreferencesData = sessionPreferencesData
        self.sortOrder = sortOrder
    }

    convenience init(machine: SavedMachine, password: String? = nil, sortOrder: Int) {
        self.init(id: machine.id,
                  name: machine.name,
                  host: machine.host,
                  port: Int(machine.port),
                  username: machine.username,
                  password: password,
                  lastConnectedAt: machine.lastConnectedAt,
                  sortOrder: sortOrder)
    }

    var savedMachine: SavedMachine {
        SavedMachine(id: id,
                     name: name,
                     host: host,
                     port: UInt16(clamping: port),
                     username: username,
                     lastConnectedAt: lastConnectedAt)
    }

    func update(from machine: SavedMachine, sortOrder: Int? = nil) {
        name = machine.name
        host = machine.host
        port = Int(machine.port)
        username = machine.username
        lastConnectedAt = machine.lastConnectedAt ?? lastConnectedAt
        updatedAt = .now

        if let sortOrder {
            self.sortOrder = sortOrder
        }
    }
}
