import Foundation
import CoreGraphics
import RoyalVNCKit

/// Owns the `VNCConnection`, implements its delegate, and publishes
/// connection state + framebuffer images for SwiftUI to observe.
final class VNCSession: NSObject, ObservableObject {
    enum Status: Equatable {
        case idle
        case connecting
        case connected
        case disconnected(String?)
    }

    /// Quality presets trading color depth for bandwidth/speed.
    ///
    /// Note: no 8-bit preset — macOS's built-in Screen Sharing server
    /// misbehaves with 8-bit sessions (connections get reset), so the
    /// fastest supported preset is 16-bit color.
    enum Quality: String, CaseIterable, Identifiable {
        case best = "Best Quality"
        case fast = "Faster (16-bit)"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .best: return "sparkles"
            case .fast: return "hare"
            }
        }
    }

    /// How touches map to the remote pointer.
    enum TouchMode {
        /// The cursor jumps to wherever you touch (absolute).
        case direct
        /// Dragging moves the cursor from where it is, like a trackpad (relative).
        case trackpad
    }

    @Published var status: Status = .idle
    @Published var image: CGImage?
    @Published private(set) var quality: Quality = .best
    @Published private(set) var isClipboardSyncEnabled = true
    @Published private(set) var touchMode: TouchMode = .direct

    /// Last known remote cursor position (framebuffer coordinates).
    private(set) var cursorLocation: CGPoint = .zero

    private(set) var connection: VNCConnection?

    private var host = ""
    private var port: UInt16 = 5900
    private var username = ""
    private var password = ""
    private var reconnectPending = false

    // MARK: - Lifecycle

    func connect(host: String, port: UInt16, username: String, password: String) {
        self.host = host
        self.port = port
        self.username = username
        self.password = password

        let settings = VNCConnection.Settings(
            isDebugLoggingEnabled: false,
            hostname: host,
            port: port,
            isShared: true,
            isScalingEnabled: true,
            useDisplayLink: true,
            inputMode: .forwardKeyboardShortcutsEvenIfInUseLocally,
            isClipboardRedirectionEnabled: isClipboardSyncEnabled,
            colorDepth: {
                switch quality {
                case .best: return .depth24Bit
                case .fast: return .depth16Bit
                }
            }(),
            frameEncodings: .default
        )

        let connection = VNCConnection(settings: settings)
        connection.delegate = self
        self.connection = connection // Keep a strong reference

        status = .connecting
        connection.connect()
    }

    func disconnect() {
        connection?.disconnect()
    }

    /// Returns the session to a clean state after the session UI is dismissed.
    func reset() {
        reconnectPending = false
        connection?.delegate = nil
        connection = nil
        image = nil
        status = .idle
    }

    // MARK: - Live settings changes
    //
    // `VNCConnection.Settings` is immutable, so changing quality or clipboard
    // sync mid-session briefly reconnects with the new settings.

    func setQuality(_ newQuality: Quality) {
        guard newQuality != quality else { return }

        quality = newQuality
        applySettingsChange()
    }

    func toggleClipboardSync() {
        isClipboardSyncEnabled.toggle()
        applySettingsChange()
    }

    private func applySettingsChange() {
        // Only reconnect for an established session; never stack reconnects.
        guard status == .connected, !reconnectPending else { return }

        reconnectPending = true
        connection?.disconnect()
    }

    /// Retries the last connection (e.g. from the disconnected screen).
    func retryConnect() {
        guard !host.isEmpty, case .disconnected = status else { return }

        connect(host: host, port: port, username: username, password: password)
    }

    // MARK: - Pointer input
    //
    // Drags are implemented by repeatedly sending mouseButtonDown at the
    // new coordinates (VNC pointer events carry position + button mask,
    // so "still down, new position" is exactly a drag), then mouseButtonUp.

    func leftButtonDown(at point: CGPoint) {
        cursorLocation = point
        connection?.mouseButtonDown(.left,
                                    x: UInt16(clamping: Int(point.x)),
                                    y: UInt16(clamping: Int(point.y)))
    }

    func leftButtonUp(at point: CGPoint) {
        cursorLocation = point
        connection?.mouseButtonUp(.left,
                                  x: UInt16(clamping: Int(point.x)),
                                  y: UInt16(clamping: Int(point.y)))
    }

    // MARK: - Trackpad-style (relative) pointer input

    func toggleTouchMode() {
        touchMode = touchMode == .direct ? .trackpad : .direct
    }

    /// Moves the cursor by a delta (framebuffer coordinates), clamped to the
    /// framebuffer. If `dragging`, the left button stays held while moving.
    func moveCursor(by delta: CGPoint, dragging: Bool) {
        guard let image else { return }

        let clamped = CGPoint(
            x: min(max(cursorLocation.x + delta.x, 0), CGFloat(image.width)),
            y: min(max(cursorLocation.y + delta.y, 0), CGFloat(image.height))
        )

        cursorLocation = clamped

        let x = UInt16(clamping: Int(clamped.x))
        let y = UInt16(clamping: Int(clamped.y))

        if dragging {
            // Position + button mask still set = drag.
            connection?.mouseButtonDown(.left, x: x, y: y)
        } else {
            connection?.mouseMove(x: x, y: y)
        }
    }

    func clickAtCursor() {
        leftButtonDown(at: cursorLocation)
        leftButtonUp(at: cursorLocation)
    }

    // MARK: - Right click & scroll

    func rightClick(at point: CGPoint) {
        cursorLocation = point

        let x = UInt16(clamping: Int(point.x))
        let y = UInt16(clamping: Int(point.y))

        connection?.mouseButtonDown(.right, x: x, y: y)
        connection?.mouseButtonUp(.right, x: x, y: y)
    }

    func rightClickAtCursor() {
        rightClick(at: cursorLocation)
    }

    enum ScrollDirection {
        case up, down
    }

    func scroll(_ direction: ScrollDirection, at point: CGPoint, steps: UInt32 = 1) {
        guard steps > 0 else { return }

        cursorLocation = point

        let x = UInt16(clamping: Int(point.x))
        let y = UInt16(clamping: Int(point.y))

        connection?.mouseWheel(direction == .up ? .up : .down,
                               x: x, y: y,
                               steps: steps)
    }

    func pressAtCursor() {
        leftButtonDown(at: cursorLocation)
    }

    func releaseAtCursor() {
        leftButtonUp(at: cursorLocation)
    }

    // MARK: - Keyboard input

    func sendText(_ text: String) {
        guard let connection else { return }

        for keyCode in VNCKeyCode.keyCodesFrom(characters: text) {
            connection.keyDown(keyCode)
            connection.keyUp(keyCode)
        }
    }

    func sendReturn() {
        connection?.keyDown(.return)
        connection?.keyUp(.return)
    }
}

// MARK: - VNCConnectionDelegate

extension VNCSession: VNCConnectionDelegate {
    func connection(_ connection: VNCConnection,
                    stateDidChange connectionState: VNCConnection.ConnectionState) {
        DispatchQueue.main.async {
            switch connectionState.status {
            case .connecting:
                self.status = .connecting
            case .connected:
                self.status = .connected
            case .disconnected:
                var message: String?

                if let error = connectionState.error as? VNCError,
                   error.shouldDisplayToUser {
                    message = error.localizedDescription
                }

                self.connection?.delegate = nil
                self.connection = nil
                self.image = nil

                if self.reconnectPending {
                    // Settings changed mid-session: reconnect with new settings.
                    // Wait for macOS's Screen Sharing daemon to release the old
                    // session first — reconnecting instantly gets the new
                    // connection reset (and rapid retries can make the Mac
                    // refuse connections for a while).
                    self.reconnectPending = false
                    self.status = .connecting

                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        // Bail if the user dismissed the session meanwhile.
                        guard self.status == .connecting, self.connection == nil else { return }

                        self.connect(host: self.host,
                                     port: self.port,
                                     username: self.username,
                                     password: self.password)
                    }
                } else {
                    self.status = .disconnected(message)
                }
            default:
                break
            }
        }
    }

    func connection(_ connection: VNCConnection,
                    credentialFor authenticationType: VNCAuthenticationType,
                    completion: @escaping (VNCCredential?) -> Void) {
        // macOS Screen Sharing usually negotiates Apple Remote Desktop auth
        // (username + password). Legacy VNC password auth only needs a password.
        if authenticationType.requiresUsername {
            completion(VNCUsernamePasswordCredential(username: username,
                                                     password: password))
        } else if authenticationType.requiresPassword {
            completion(VNCPasswordCredential(password: password))
        } else {
            completion(nil)
        }
    }

    func connection(_ connection: VNCConnection,
                    didCreateFramebuffer framebuffer: VNCFramebuffer) {
        DispatchQueue.main.async {
            self.image = framebuffer.cgImage

            // Start the trackpad cursor at the center of the screen.
            if self.cursorLocation == .zero, let image = self.image {
                self.cursorLocation = CGPoint(x: image.width / 2, y: image.height / 2)
            }
        }
    }

    func connection(_ connection: VNCConnection,
                    didResizeFramebuffer framebuffer: VNCFramebuffer) {
        DispatchQueue.main.async {
            self.image = framebuffer.cgImage
        }
    }

    func connection(_ connection: VNCConnection,
                    didUpdateFramebuffer framebuffer: VNCFramebuffer,
                    x: UInt16, y: UInt16,
                    width: UInt16, height: UInt16) {
        // TODO: For better performance, only invalidate the dirty rect
        // (x/y/width/height) instead of republishing the whole image.
        DispatchQueue.main.async {
            self.image = framebuffer.cgImage
        }
    }

    func connection(_ connection: VNCConnection,
                    didUpdateCursor cursor: VNCCursor) {
        // TODO: Render the remote cursor shape if desired.
    }
}
