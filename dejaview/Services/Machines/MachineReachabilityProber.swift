import Foundation
import Network

enum MachineReachabilityProber {
    @MainActor
    static func status(host: String,
                       port: UInt16,
                       timeout: Duration = .seconds(2)) async -> MachineReachabilityStatus {
        await MachineReachabilityProbe(host: host, port: port, timeout: timeout).start()
    }
}

@MainActor
private final class MachineReachabilityProbe {
    private let host: String
    private let port: UInt16
    private let timeout: Duration

    private var connection: NWConnection?
    private var continuation: CheckedContinuation<MachineReachabilityStatus, Never>?
    private var timeoutTask: Task<Void, Never>?
    private var didFinish = false

    init(host: String, port: UInt16, timeout: Duration) {
        self.host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        self.port = port
        self.timeout = timeout
    }

    func start() async -> MachineReachabilityStatus {
        guard !host.isEmpty,
              let networkPort = NWEndpoint.Port(rawValue: port) else {
            return .unreachable
        }

        return await withCheckedContinuation { continuation in
            self.continuation = continuation

            let connection = NWConnection(host: NWEndpoint.Host(host),
                                          port: networkPort,
                                          using: .tcp)
            self.connection = connection

            connection.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    self?.handle(state)
                }
            }

            let timeout = self.timeout
            timeoutTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: timeout)
                guard !Task.isCancelled else { return }
                self?.finish(.unreachable)
            }

            connection.start(queue: .main)
        }
    }

    private func handle(_ state: NWConnection.State) {
        switch state {
        case .ready:
            finish(.reachable)
        case .waiting, .failed:
            finish(.unreachable)
        case .cancelled:
            break
        default:
            break
        }
    }

    private func finish(_ status: MachineReachabilityStatus) {
        guard !didFinish else { return }

        didFinish = true
        timeoutTask?.cancel()
        timeoutTask = nil
        connection?.cancel()
        connection = nil
        continuation?.resume(returning: status)
        continuation = nil
    }
}
