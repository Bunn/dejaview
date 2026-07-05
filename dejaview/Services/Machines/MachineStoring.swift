import Combine
import Foundation

@MainActor
protocol MachineStoring: ObservableObject, AnyObject {
    var machines: [SavedMachine] { get }
    var recentConnections: [ConnectionHistoryEntry] { get }

    func reload()
    func add(_ machine: SavedMachine, password: String)
    func update(_ machine: SavedMachine, password: String)
    func delete(_ machine: SavedMachine)
    func contains(_ machine: SavedMachine) -> Bool
    func machine(withID id: UUID) -> SavedMachine?
    func password(for machine: SavedMachine) -> String
    func recordConnection(to machine: SavedMachine)
}
