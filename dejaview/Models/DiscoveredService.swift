import Foundation

/// A Screen Sharing server discovered via Bonjour, resolved to host + port.
struct DiscoveredService: Identifiable, Equatable {
    let id: String
    let name: String
    var host: String?
    var port: UInt16?

    var isResolved: Bool { host != nil && port != nil }
}
