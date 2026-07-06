import Foundation
import Network
import Observation
import OSLog

/// Discovers Screen Sharing / VNC servers (`_rfb._tcp`) on the local network
/// and eagerly resolves each one to a concrete IP address + port, preferring
/// IPv4 (link-local IPv6 addresses often fail to connect).
@MainActor
@Observable
final class BonjourBrowser: BonjourBrowsing {
    var services: [DiscoveredService] = []

    @ObservationIgnored
    private var browser: NWBrowser?
    @ObservationIgnored
    private var resolveConnections: [String: NWConnection] = [:]
    @ObservationIgnored
    private var resolveTimeouts: [String: Task<Void, Never>] = [:]
    @ObservationIgnored
    private var resolveRetryTasks: [String: Task<Void, Never>] = [:]
    @ObservationIgnored
    private var resolveAttempts: [String: Int] = [:]
    @ObservationIgnored
    private var serviceIDsNeedingResolutionRefresh = Set<String>()

    @ObservationIgnored
    private let resolveTimeout: TimeInterval = 5
    @ObservationIgnored
    private let resolveRetryDelay: TimeInterval = 2
    @ObservationIgnored
    private let maxResolveAttempts = 3

    func start() {
        guard browser == nil else {
            AppLog.discovery.debug("Ignoring discovery start because browser is already active")
            return
        }

        AppLog.discovery.info("Starting Bonjour browser for _rfb._tcp")

        let browser = NWBrowser(for: .bonjour(type: "_rfb._tcp", domain: nil),
                                using: .tcp)

        browser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor in
                self?.update(with: results)
            }
        }

        browser.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                self?.handleBrowserState(state)
            }
        }

        browser.start(queue: .main)
        self.browser = browser
    }

    func stop() {
        stop(keepingCurrentServices: false)
    }

    func restart(keepingCurrentServices: Bool) {
        AppLog.discovery.info("Restarting Bonjour browser; keepingCurrentServices=\(keepingCurrentServices, privacy: .public)")

        stop(keepingCurrentServices: keepingCurrentServices)
        start()
    }

    private func stop(keepingCurrentServices: Bool) {
        AppLog.discovery.info("Stopping Bonjour browser; keepingCurrentServices=\(keepingCurrentServices, privacy: .public)")

        browser?.cancel()
        browser = nil

        cancelAllResolutions()
        resolveAttempts.removeAll()

        if keepingCurrentServices {
            serviceIDsNeedingResolutionRefresh = Set(services.map(\.id))
        } else {
            serviceIDsNeedingResolutionRefresh.removeAll()
            services.removeAll()
        }
    }

    // MARK: - Private

    private func handleBrowserState(_ state: NWBrowser.State) {
        switch state {
        case .setup:
            AppLog.discovery.debug("Bonjour browser setup")

        case .ready:
            AppLog.discovery.info("Bonjour browser ready")

        case .waiting(let error):
            AppLog.discovery.warning("Bonjour browser waiting: \(String(describing: error), privacy: .public)")
            cancelAllResolutions()
            resolveAttempts.removeAll()
            serviceIDsNeedingResolutionRefresh.removeAll()
            services.removeAll()

        case .failed(let error):
            AppLog.discovery.error("Bonjour browser failed: \(String(describing: error), privacy: .public)")
            restartAfterBrowserFailure()

        case .cancelled:
            AppLog.discovery.debug("Bonjour browser cancelled")

        @unknown default:
            AppLog.discovery.warning("Bonjour browser entered an unknown state")
        }
    }

    private func restartAfterBrowserFailure() {
        browser?.cancel()
        browser = nil

        cancelAllResolutions()
        resolveAttempts.removeAll()
        serviceIDsNeedingResolutionRefresh.removeAll()
        services.removeAll()

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2))
            self?.start()
        }
    }

    private func update(with results: Set<NWBrowser.Result>) {
        AppLog.discovery.debug("Bonjour results changed; count=\(results.count, privacy: .public)")

        var activeNames = Set<String>()
        var updated: [DiscoveredService] = []

        for result in results {
            guard case .service(let name, _, _, _) = result.endpoint else { continue }

            activeNames.insert(name)

            if let existing = services.first(where: { $0.id == name }) {
                updated.append(existing)

                let needsResolutionRefresh = serviceIDsNeedingResolutionRefresh.remove(name) != nil
                if (!existing.isResolved || needsResolutionRefresh),
                   resolveConnections[name] == nil,
                   resolveRetryTasks[name] == nil {
                    resolve(result, name: name, preferIPv4: true)
                }
            } else {
                AppLog.discovery.info("Discovered Screen Sharing service '\(name, privacy: .public)'")
                updated.append(DiscoveredService(id: name, name: name))
                resolve(result, name: name, preferIPv4: true)
            }
        }

        for removedName in Set(services.map(\.id)).subtracting(activeNames) {
            AppLog.discovery.info("Screen Sharing service removed '\(removedName, privacy: .public)'")
            cancelResolution(for: removedName)
            resolveAttempts[removedName] = nil
            serviceIDsNeedingResolutionRefresh.remove(removedName)
        }

        services = updated.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Resolves a Bonjour service by opening a short-lived TCP connection and
    /// reading the resolved remote endpoint from its network path.
    private func resolve(_ result: NWBrowser.Result, name: String, preferIPv4: Bool) {
        cancelResolution(for: name)

        if preferIPv4 {
            resolveAttempts[name, default: 0] += 1
        }

        let attempt = resolveAttempts[name, default: 1]
        AppLog.discovery.debug("Resolving service '\(name, privacy: .public)' attempt=\(attempt, privacy: .public) preferIPv4=\(preferIPv4, privacy: .public)")

        let parameters = NWParameters.tcp

        if preferIPv4,
           let ip = parameters.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
            ip.version = .v4
        }

        let connection = NWConnection(to: result.endpoint, using: parameters)
        resolveConnections[name] = connection
        scheduleResolveTimeout(for: name,
                               result: result,
                               connection: connection,
                               preferIPv4: preferIPv4)

        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                guard let self else { return }

                switch state {
                case .ready:
                    guard self.finishResolutionConnection(connection, name: name) else { return }

                    guard case .hostPort(let host, let port)? = connection.currentPath?.remoteEndpoint else {
                        AppLog.discovery.warning("Resolved service '\(name, privacy: .public)' without a hostPort endpoint")
                        if preferIPv4 {
                            self.resolve(result, name: name, preferIPv4: false)
                        } else {
                            self.finishResolveFailure(result, name: name)
                        }
                        return
                    }

                    let hostString = Self.string(from: host)
                    AppLog.discovery.info("Resolved service '\(name, privacy: .public)' to \(hostString, privacy: .public):\(port.rawValue, privacy: .public)")

                    if let index = self.services.firstIndex(where: { $0.id == name }) {
                        self.services[index].host = hostString
                        self.services[index].port = port.rawValue
                    }

                    self.resolveAttempts[name] = nil

                case .waiting(let error):
                    AppLog.discovery.debug("Resolve waiting for '\(name, privacy: .public)': \(String(describing: error), privacy: .public)")

                case .failed(let error):
                    guard self.finishResolutionConnection(connection, name: name) else { return }
                    AppLog.discovery.warning("Resolve failed for '\(name, privacy: .public)': \(String(describing: error), privacy: .public)")
                    // IPv4 didn't work out; retry without the version constraint.
                    if preferIPv4 {
                        self.resolve(result, name: name, preferIPv4: false)
                    } else {
                        self.finishResolveFailure(result, name: name)
                    }

                case .cancelled:
                    _ = self.finishResolutionConnection(connection, name: name)

                default:
                    break
                }
            }
        }

        connection.start(queue: .main)
    }

    private func scheduleResolveTimeout(for name: String,
                                        result: NWBrowser.Result,
                                        connection: NWConnection,
                                        preferIPv4: Bool) {
        resolveTimeouts[name]?.cancel()

        let resolveTimeout = Int(resolveTimeout * 1000)
        let timeout = Task { @MainActor [weak self, weak connection] in
            try? await Task.sleep(for: .milliseconds(resolveTimeout))
            guard !Task.isCancelled else { return }
            guard let self, let connection,
                  self.resolveConnections[name] === connection else { return }

            AppLog.discovery.warning("Resolve timed out for '\(name, privacy: .public)' preferIPv4=\(preferIPv4, privacy: .public)")
            connection.cancel()
            _ = self.finishResolutionConnection(connection, name: name)

            if preferIPv4 {
                self.resolve(result, name: name, preferIPv4: false)
            } else {
                self.finishResolveFailure(result, name: name)
            }
        }

        resolveTimeouts[name] = timeout
    }

    private func finishResolutionConnection(_ connection: NWConnection, name: String) -> Bool {
        guard resolveConnections[name] === connection else { return false }

        resolveTimeouts[name]?.cancel()
        resolveTimeouts[name] = nil
        resolveConnections[name] = nil
        connection.cancel()
        return true
    }

    private func finishResolveFailure(_ result: NWBrowser.Result, name: String) {
        guard services.contains(where: { $0.id == name && !$0.isResolved }) else { return }

        let attempts = resolveAttempts[name, default: 0]

        guard attempts < maxResolveAttempts else {
            AppLog.discovery.error("Giving up resolving service '\(name, privacy: .public)' after \(attempts, privacy: .public) attempts")
            services.removeAll { $0.id == name && !$0.isResolved }
            resolveAttempts[name] = nil
            serviceIDsNeedingResolutionRefresh.remove(name)
            return
        }

        scheduleResolveRetry(result, name: name)
    }

    private func scheduleResolveRetry(_ result: NWBrowser.Result, name: String) {
        guard resolveRetryTasks[name] == nil else { return }

        AppLog.discovery.info("Scheduling resolve retry for '\(name, privacy: .public)'")

        let resolveRetryDelay = Int(resolveRetryDelay * 1000)
        let retry = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(resolveRetryDelay))
            guard !Task.isCancelled else { return }
            guard let self else { return }

            self.resolveRetryTasks[name] = nil

            guard self.services.contains(where: { $0.id == name && !$0.isResolved }) else { return }

            self.resolve(result, name: name, preferIPv4: true)
        }

        resolveRetryTasks[name] = retry
    }

    private func cancelAllResolutions() {
        resolveConnections.values.forEach { $0.cancel() }
        resolveConnections.removeAll()

        resolveTimeouts.values.forEach { $0.cancel() }
        resolveTimeouts.removeAll()

        resolveRetryTasks.values.forEach { $0.cancel() }
        resolveRetryTasks.removeAll()
    }

    private func cancelResolution(for name: String) {
        resolveConnections[name]?.cancel()
        resolveConnections[name] = nil

        resolveTimeouts[name]?.cancel()
        resolveTimeouts[name] = nil

        resolveRetryTasks[name]?.cancel()
        resolveRetryTasks[name] = nil
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
