import Foundation

struct AutomaticReconnectPolicy: Sendable {
    private let retryDelays: [TimeInterval]

    init(retryDelays: [TimeInterval] = [1, 2, 4, 8, 15]) {
        precondition(!retryDelays.isEmpty)
        precondition(retryDelays.allSatisfy { $0 >= 0 })
        self.retryDelays = retryDelays
    }

    var maximumAttempts: Int {
        retryDelays.count
    }

    func delay(beforeAttempt attempt: Int) -> TimeInterval? {
        guard retryDelays.indices.contains(attempt - 1) else { return nil }
        return retryDelays[attempt - 1]
    }
}
