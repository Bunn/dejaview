import Foundation

enum MachineReachabilityStatus: Equatable, Sendable {
    case checking
    case waking
    case reachable
    case unreachable

    var title: String {
        switch self {
        case .checking:
            "Checking"
        case .waking:
            "Waking"
        case .reachable:
            "Reachable"
        case .unreachable:
            "Unreachable"
        }
    }
}
