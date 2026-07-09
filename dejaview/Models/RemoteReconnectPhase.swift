import Foundation

enum RemoteReconnectPhase: Equatable, Sendable {
    case waitingForNetwork
    case waiting(until: Date)
    case connecting
}
