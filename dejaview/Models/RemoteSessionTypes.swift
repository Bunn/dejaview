import Foundation

enum RemoteSessionStatus: Equatable {
    case idle
    case connecting
    case connected
    case disconnected(String?)
}

/// Quality presets trading color depth for bandwidth/speed.
///
/// Note: no 8-bit preset because macOS's built-in Screen Sharing server
/// misbehaves with 8-bit sessions.
enum RemoteSessionQuality: String, CaseIterable, Identifiable {
    case best = "Best Quality"
    case fast = "Faster (16-bit)"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .best:
            "sparkles"
        case .fast:
            "hare"
        }
    }
}

/// How touches map to the remote pointer.
enum RemoteTouchMode {
    /// The cursor jumps to wherever you touch.
    case direct
    /// Dragging moves the cursor from where it is, like a trackpad.
    case trackpad
}

enum RemoteScrollDirection {
    case up
    case down
    case left
    case right
}
