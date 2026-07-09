import Foundation

struct RemoteReconnectState: Equatable, Sendable {
    let attempt: Int
    let maximumAttempts: Int
    let phase: RemoteReconnectPhase

    var canRetryImmediately: Bool {
        if case .waiting = phase {
            true
        } else {
            false
        }
    }
}
