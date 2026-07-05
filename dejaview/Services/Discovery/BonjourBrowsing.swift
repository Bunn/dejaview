import Combine

protocol BonjourBrowsing: ObservableObject, AnyObject {
    var services: [DiscoveredService] { get }

    func start()
    func stop()
}
