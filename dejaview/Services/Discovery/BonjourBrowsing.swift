@MainActor
protocol BonjourBrowsing: AnyObject {
    var services: [DiscoveredService] { get }

    func start()
    func stop()
}
