import Foundation
import OSLog

enum AppLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.example.dejaview"

    static let app = Logger(subsystem: subsystem, category: "App")
    static let discovery = Logger(subsystem: subsystem, category: "Discovery")
    static let storage = Logger(subsystem: subsystem, category: "Storage")
    static let session = Logger(subsystem: subsystem, category: "Session")
    static let rendering = Logger(subsystem: subsystem, category: "Rendering")
    static let pointsOfInterest = Logger(subsystem: subsystem, category: "PointsOfInterest")
    static let input = Logger(subsystem: subsystem, category: "Input")
    static let ui = Logger(subsystem: subsystem, category: "UI")
    static let reachability = Logger(subsystem: subsystem, category: "Reachability")
    static let subscriptions = Logger(subsystem: subsystem, category: "Subscriptions")
}
