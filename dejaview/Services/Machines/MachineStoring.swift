import Combine
import Foundation

protocol MachineStoring: ObservableObject, AnyObject {
    var machines: [SavedMachine] { get }

    func reload()
    func add(_ machine: SavedMachine, password: String)
    func update(_ machine: SavedMachine, password: String)
    func delete(_ machine: SavedMachine)
    func contains(_ machine: SavedMachine) -> Bool
    func machine(withID id: UUID) -> SavedMachine?
    func password(for machine: SavedMachine) -> String
}
