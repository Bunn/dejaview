import Foundation

enum MachineReachabilityStatus: Equatable, Sendable {
    case checking
    case reachable
    case unreachable

    var title: String {
        switch self {
        case .checking:
            "Checking"
        case .reachable:
            "Reachable"
        case .unreachable:
            "Unreachable"
        }
    }
}
