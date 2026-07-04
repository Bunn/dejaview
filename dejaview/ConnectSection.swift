import SwiftUI

enum ConnectSection: String, CaseIterable, Hashable, Identifiable {
    case hosts
    case nearby
    case manual

    var id: Self { self }

    var title: String {
        switch self {
        case .hosts:
            "Hosts"
        case .nearby:
            "Nearby Macs"
        case .manual:
            "Manual"
        }
    }

    var subtitle: String {
        switch self {
        case .hosts:
            "Saved and discovered screen sharing targets."
        case .nearby:
            "Macs advertising Screen Sharing on this network."
        case .manual:
            "Connect directly with a host name or IP address."
        }
    }

    var systemImage: String {
        switch self {
        case .hosts:
            "rectangle.connected.to.line.below"
        case .nearby:
            "dot.radiowaves.left.and.right"
        case .manual:
            "keyboard"
        }
    }
}
