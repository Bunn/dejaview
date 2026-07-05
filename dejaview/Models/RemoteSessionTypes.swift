import Foundation
import CoreGraphics

enum RemoteSessionStatus: Equatable {
    case idle
    case connecting
    case connected
    case disconnected(String?)

    var logDescription: String {
        switch self {
        case .idle:
            "idle"
        case .connecting:
            "connecting"
        case .connected:
            "connected"
        case .disconnected(let message):
            "disconnected(messageProvided=\(message != nil))"
        }
    }
}

/// Quality presets for the VNC stream.
///
/// RoyalVNCKit stores its display framebuffer as 32bpp BGRA and its optimized
/// Tight/ZRLE paths are 24-bit/32bpp-oriented. Requesting 16-bit forces
/// per-pixel expansion back to BGRA and can spike CPU on large remote
/// framebuffers, so only the optimized 24-bit path is exposed.
enum RemoteSessionQuality: String, CaseIterable, Identifiable {
    case best = "Best Quality"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .best:
            "sparkles"
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

struct RemoteDisplay: Identifiable, Equatable, Sendable {
    let id: UInt32
    let name: String
    let frame: CGRect

    var menuTitle: String {
        let width = Int(frame.width.rounded())
        let height = Int(frame.height.rounded())

        return "\(name) (\(width)x\(height))"
    }

    var logDescription: String {
        let minX = Int(frame.minX.rounded())
        let minY = Int(frame.minY.rounded())
        let width = Int(frame.width.rounded())
        let height = Int(frame.height.rounded())

        return "id=\(id) name='\(name)' frame=(x:\(minX),y:\(minY),w:\(width),h:\(height))"
    }
}

enum RemoteDisplaySelection: Hashable, Sendable {
    case all
    case display(UInt32)
    case region(RemoteDisplayRegion)

    var id: String {
        switch self {
        case .all:
            "all"
        case .display(let id):
            "display-\(id)"
        case .region(let region):
            "region-\(region.rawValue)"
        }
    }

    var logDescription: String {
        switch self {
        case .all:
            "all"
        case .display(let id):
            "display:\(id)"
        case .region(let region):
            "region:\(region.rawValue)"
        }
    }
}

enum RemoteDisplayRegion: String, CaseIterable, Sendable {
    case left
    case right
    case top
    case bottom

    var title: String {
        switch self {
        case .left:
            "Left Display"
        case .right:
            "Right Display"
        case .top:
            "Top Display"
        case .bottom:
            "Bottom Display"
        }
    }

    var systemImage: String {
        switch self {
        case .left, .right:
            "rectangle.split.2x1"
        case .top, .bottom:
            "rectangle.split.1x2"
        }
    }

    func frame(in bounds: CGRect) -> CGRect {
        switch self {
        case .left:
            let maxX = floor(bounds.midX)
            return CGRect(x: bounds.minX,
                          y: bounds.minY,
                          width: maxX - bounds.minX,
                          height: bounds.height)
        case .right:
            let minX = floor(bounds.midX)
            return CGRect(x: minX,
                          y: bounds.minY,
                          width: bounds.maxX - minX,
                          height: bounds.height)
        case .top:
            let maxY = floor(bounds.midY)
            return CGRect(x: bounds.minX,
                          y: bounds.minY,
                          width: bounds.width,
                          height: maxY - bounds.minY)
        case .bottom:
            let minY = floor(bounds.midY)
            return CGRect(x: bounds.minX,
                          y: minY,
                          width: bounds.width,
                          height: bounds.maxY - minY)
        }
    }
}

struct RemoteDisplayOption: Identifiable, Equatable, Sendable {
    let selection: RemoteDisplaySelection
    let title: String
    let systemImage: String

    var id: String {
        selection.id
    }

    var logDescription: String {
        "\(selection.logDescription) title='\(title)'"
    }
}
