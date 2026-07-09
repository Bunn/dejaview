import SwiftUI

enum ConnectSection: String, CaseIterable, Hashable, Identifiable {
    case hosts
    case recents
    case nearby

    var id: Self { self }

    var title: String {
        switch self {
        case .hosts:
            "Hosts"
        case .recents:
            "Recents"
        case .nearby:
            "Nearby Macs"
        }
    }

    var subtitle: String {
        switch self {
        case .hosts:
            "Saved and discovered screen sharing targets."
        case .recents:
            "Previously connected Macs and session details."
        case .nearby:
            "Macs advertising Screen Sharing on this network."
        }
    }

    var systemImage: String {
        switch self {
        case .hosts:
            "rectangle.connected.to.line.below"
        case .recents:
            "clock.arrow.circlepath"
        case .nearby:
            "dot.radiowaves.left.and.right"
        }
    }
}
