import Foundation
import Network

/// A Screen Sharing server discovered via Bonjour, resolved to host + port.
struct DiscoveredService: Identifiable, Equatable {
    let id: String
    let name: String
    var host: String?
    var port: UInt16?

    var isResolved: Bool { host != nil && port != nil }
}

/// Discovers Screen Sharing / VNC servers (`_rfb._tcp`) on the local network
/// and eagerly resolves each one to a concrete IP address + port, preferring
/// IPv4 (link-local IPv6 addresses often fail to connect).
final class BonjourBrowser: ObservableObject {
    @Published var services: [DiscoveredService] = []

    private var browser: NWBrowser?
    private var resolveConnections: [String: NWConnection] = [:]

    func start() {
        guard browser == nil else { return }

        let browser = NWBrowser(for: .bonjour(type: "_rfb._tcp", domain: nil),
                                using: .tcp)

        browser.browseResultsChangedHandler = { [weak self] results, _ in
            DispatchQueue.main.async {
                self?.update(with: results)
            }
        }

        browser.start(queue: .main)
        self.browser = browser
    }

    func stop() {
        browser?.cancel()
        browser = nil

        resolveConnections.values.forEach { $0.cancel() }
        resolveConnections.removeAll()
    }

    // MARK: - Private

    private func update(with results: Set<NWBrowser.Result>) {
        var updated: [DiscoveredService] = []

        for result in results {
            guard case .service(let name, _, _, _) = result.endpoint else { continue }

            if let existing = services.first(where: { $0.id == name }) {
                updated.append(existing)
            } else {
                updated.append(DiscoveredService(id: name, name: name))
                resolve(result, name: name, preferIPv4: true)
            }
        }

        services = updated.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Resolves a Bonjour service by opening a short-lived TCP connection and
    /// reading the resolved remote endpoint from its network path.
    private func resolve(_ result: NWBrowser.Result, name: String, preferIPv4: Bool) {
        resolveConnections[name]?.cancel()

        let parameters = NWParameters.tcp

        if preferIPv4,
           let ip = parameters.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
            ip.version = .v4
        }

        let connection = NWConnection(to: result.endpoint, using: parameters)
        resolveConnections[name] = connection

        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }

            switch state {
            case .ready:
                defer {
                    connection.cancel()
                    self.resolveConnections[name] = nil
                }

                guard case .hostPort(let host, let port)? = connection.currentPath?.remoteEndpoint else {
                    return
                }

                let hostString = Self.string(from: host)

                DispatchQueue.main.async {
                    if let index = self.services.firstIndex(where: { $0.id == name }) {
                        self.services[index].host = hostString
                        self.services[index].port = port.rawValue
                    }
                }

            case .failed:
                connection.cancel()
                self.resolveConnections[name] = nil

                // IPv4 didn't work out; retry without the version constraint.
                if preferIPv4 {
                    self.resolve(result, name: name, preferIPv4: false)
                }

            default:
                break
            }
        }

        connection.start(queue: .main)
    }

    private static func string(from host: NWEndpoint.Host) -> String {
        var hostString: String

        switch host {
        case .ipv4(let address):
            hostString = "\(address)"
        case .ipv6(let address):
            hostString = "\(address)"
        case .name(let name, _):
            hostString = name
        @unknown default:
            hostString = "\(host)"
        }

        // Strip interface-scope suffixes like "%en0".
        if let percentIndex = hostString.firstIndex(of: "%") {
            hostString = String(hostString[..<percentIndex])
        }

        return hostString
    }
}
