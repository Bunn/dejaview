import Foundation

enum RemoteFrameRate: Int, CaseIterable, Codable, Identifiable, Sendable {
    case batterySaver = 10
    case balanced = 15
    case responsive = 30

    var id: Self { self }

    var title: String {
        switch self {
        case .batterySaver:
            "Battery Saver"
        case .balanced:
            "Balanced"
        case .responsive:
            "Responsive"
        }
    }

    var systemImage: String {
        switch self {
        case .batterySaver:
            "battery.100percent"
        case .balanced:
            "circle.lefthalf.filled"
        case .responsive:
            "bolt.fill"
        }
    }

    var updateInterval: TimeInterval {
        1 / TimeInterval(rawValue)
    }
}
