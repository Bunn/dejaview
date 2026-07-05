import Network
import Observation

enum NetworkPathStatus: Equatable, Sendable {
    case satisfied
    case unsatisfied
    case requiresConnection

    init(_ status: NWPath.Status) {
        switch status {
        case .satisfied:
            self = .satisfied
        case .unsatisfied:
            self = .unsatisfied
        case .requiresConnection:
            self = .requiresConnection
        @unknown default:
            self = .unsatisfied
        }
    }

    var logDescription: String {
        switch self {
        case .satisfied:
            "satisfied"
        case .unsatisfied:
            "unsatisfied"
        case .requiresConnection:
            "requiresConnection"
        }
    }
}

struct NetworkPathSnapshot: Equatable, Sendable {
    let status: NetworkPathStatus
    let usesWiFi: Bool
    let usesCellular: Bool
    let usesWiredEthernet: Bool
    let isExpensive: Bool
    let isConstrained: Bool

    init(_ path: NWPath) {
        status = NetworkPathStatus(path.status)
        usesWiFi = path.usesInterfaceType(.wifi)
        usesCellular = path.usesInterfaceType(.cellular)
        usesWiredEthernet = path.usesInterfaceType(.wiredEthernet)
        isExpensive = path.isExpensive
        isConstrained = path.isConstrained
    }

    var logDescription: String {
        "status=\(status.logDescription) wifi=\(usesWiFi) cellular=\(usesCellular) wired=\(usesWiredEthernet) expensive=\(isExpensive) constrained=\(isConstrained)"
    }
}

@MainActor
@Observable
final class NetworkPathObserver {
    private(set) var snapshot: NetworkPathSnapshot?

    @ObservationIgnored
    private var monitor: NWPathMonitor?

    func start() {
        guard monitor == nil else { return }

        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            let snapshot = NetworkPathSnapshot(path)

            Task { @MainActor in
                self?.snapshot = snapshot
            }
        }

        monitor.start(queue: .main)
        self.monitor = monitor
    }

    func stop() {
        monitor?.cancel()
        monitor = nil
        snapshot = nil
    }
}
