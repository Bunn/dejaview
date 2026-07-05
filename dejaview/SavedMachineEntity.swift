import AppIntents
import Foundation

struct SavedMachineEntity: AppEntity, Identifiable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Saved Mac")
    static let defaultQuery = SavedMachineQuery()

    let id: UUID
    let name: String
    let host: String
    let port: UInt16
    let username: String

    init(machine: SavedMachine) {
        id = machine.id
        name = machine.name
        host = machine.host
        port = machine.port
        username = machine.username
    }

    var displayName: String {
        name.isEmpty ? host : name
    }

    var subtitle: String {
        let hostPort = "\(host):\(String(port))"
        return username.isEmpty ? hostPort : "\(username)@\(hostPort)"
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(displayName)", subtitle: "\(subtitle)")
    }
}

struct SavedMachineQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [SavedMachineEntity.ID]) async throws -> [SavedMachineEntity] {
        MachineStore.savedMachines()
            .filter { identifiers.contains($0.id) }
            .map(SavedMachineEntity.init)
    }

    func entities(matching string: String) async throws -> [SavedMachineEntity] {
        let query = string.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            return try await suggestedEntities()
        }

        return MachineStore.savedMachines()
            .filter { machine in
                machine.displayName.localizedCaseInsensitiveContains(query) ||
                machine.subtitle.localizedCaseInsensitiveContains(query)
            }
            .map(SavedMachineEntity.init)
    }

    func suggestedEntities() async throws -> [SavedMachineEntity] {
        MachineStore.savedMachines().map(SavedMachineEntity.init)
    }

    func defaultResult() async -> SavedMachineEntity? {
        MachineStore.savedMachines().first.map(SavedMachineEntity.init)
    }
}
