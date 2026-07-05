import Foundation
import CoreGraphics
import OSLog
import RoyalVNCKit

/// Owns the `VNCConnection`, implements its delegate, and publishes
/// connection state + framebuffer images for SwiftUI to observe.
final class VNCSession: NSObject, ObservableObject, RemoteSessionControlling {
    @Published var status: RemoteSessionStatus = .idle
    @Published var image: CGImage?
    @Published private(set) var quality: RemoteSessionQuality = .best
    @Published private(set) var isClipboardSyncEnabled = true
    @Published private(set) var touchMode: RemoteTouchMode = .direct

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
        AppLog.session.info("Connecting to VNC host \(host, privacy: .public):\(port, privacy: .public); usernameProvided=\(!username.isEmpty, privacy: .public); quality=\(self.quality.rawValue, privacy: .public); clipboard=\(self.isClipboardSyncEnabled, privacy: .public)")

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
        AppLog.session.info("Disconnect requested")
        connection?.disconnect()
    }

    /// Returns the session to a clean state after the session UI is dismissed.
    func reset() {
        AppLog.session.info("Resetting session state")
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

    func setQuality(_ newQuality: RemoteSessionQuality) {
        guard newQuality != quality else { return }

        AppLog.session.info("Changing quality from \(self.quality.rawValue, privacy: .public) to \(newQuality.rawValue, privacy: .public)")
        quality = newQuality
        applySettingsChange()
    }

    func toggleClipboardSync() {
        isClipboardSyncEnabled.toggle()
        AppLog.session.info("Clipboard sync toggled; enabled=\(self.isClipboardSyncEnabled, privacy: .public)")
        applySettingsChange()
    }

    private func applySettingsChange() {
        // Only reconnect for an established session; never stack reconnects.
        guard status == .connected, !reconnectPending else {
            AppLog.session.debug("Skipped settings reconnect; status=\(String(describing: self.status), privacy: .public) reconnectPending=\(self.reconnectPending, privacy: .public)")
            return
        }

        AppLog.session.info("Applying settings change by reconnecting session")
        reconnectPending = true
        connection?.disconnect()
    }

    /// Retries the last connection (e.g. from the disconnected screen).
    func retryConnect() {
        guard !host.isEmpty, case .disconnected = status else {
            AppLog.session.warning("Retry requested but no disconnected session is available")
            return
        }

        AppLog.session.info("Retrying connection to \(self.host, privacy: .public):\(self.port, privacy: .public)")
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
        AppLog.input.info("Touch mode changed to \(String(describing: self.touchMode), privacy: .public)")
    }

    /// Moves the cursor by a delta (framebuffer coordinates), clamped to the
    /// framebuffer. If `dragging`, the left button stays held while moving.
    func moveCursor(by delta: CGPoint, dragging: Bool) {
        guard let image else { return }

        let clamped = CGPoint(
            x: min(max(cursorLocation.x + delta.x, 0), CGFloat(image.width)),
            y: min(max(cursorLocation.y + delta.y, 0), CGFloat(image.height))
        )

        moveCursor(to: clamped, dragging: dragging)
    }

    func moveCursor(to point: CGPoint, dragging: Bool = false) {
        guard let image else { return }

        let clamped = CGPoint(
            x: min(max(point.x, 0), CGFloat(image.width)),
            y: min(max(point.y, 0), CGFloat(image.height))
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
        AppLog.input.debug("Left click at cursor x=\(self.cursorLocation.x, privacy: .public) y=\(self.cursorLocation.y, privacy: .public)")
        leftButtonDown(at: cursorLocation)
        leftButtonUp(at: cursorLocation)
    }

    // MARK: - Right click & scroll

    func rightClick(at point: CGPoint) {
        AppLog.input.debug("Right click at x=\(point.x, privacy: .public) y=\(point.y, privacy: .public)")
        cursorLocation = point

        let x = UInt16(clamping: Int(point.x))
        let y = UInt16(clamping: Int(point.y))

        connection?.mouseButtonDown(.right, x: x, y: y)
        connection?.mouseButtonUp(.right, x: x, y: y)
    }

    func rightClickAtCursor() {
        rightClick(at: cursorLocation)
    }

    func scroll(_ direction: RemoteScrollDirection, steps: UInt32 = 1) {
        guard steps > 0 else { return }

        AppLog.input.debug("Scroll \(String(describing: direction), privacy: .public) steps=\(steps, privacy: .public) at x=\(self.cursorLocation.x, privacy: .public) y=\(self.cursorLocation.y, privacy: .public)")
        let x = UInt16(clamping: Int(cursorLocation.x))
        let y = UInt16(clamping: Int(cursorLocation.y))

        let wheel: VNCMouseWheel

        switch direction {
        case .up:
            wheel = .up
        case .down:
            wheel = .down
        case .left:
            wheel = .left
        case .right:
            wheel = .right
        }

        connection?.mouseWheel(wheel, x: x, y: y, steps: steps)
    }

    func pressAtCursor() {
        leftButtonDown(at: cursorLocation)
    }

    func releaseAtCursor() {
        leftButtonUp(at: cursorLocation)
    }

    // MARK: - Keyboard input

    func sendText(_ text: String, modifiers: [VNCKeyCode] = []) {
        guard let connection else { return }

        AppLog.input.debug("Sending text to remote; characterCount=\(text.count, privacy: .public) modifiers=\(modifiers.count, privacy: .public)")
        modifiers.forEach { connection.keyDown($0) }

        for keyCode in VNCKeyCode.keyCodesFrom(characters: text) {
            connection.keyDown(keyCode)
            connection.keyUp(keyCode)
        }

        modifiers.reversed().forEach { connection.keyUp($0) }
    }

    func sendKey(_ keyCode: VNCKeyCode, modifiers: [VNCKeyCode] = []) {
        guard let connection else { return }

        AppLog.input.debug("Sending key to remote; key=\(String(describing: keyCode), privacy: .public) modifiers=\(modifiers.count, privacy: .public)")
        modifiers.forEach { connection.keyDown($0) }
        connection.keyDown(keyCode)
        connection.keyUp(keyCode)
        modifiers.reversed().forEach { connection.keyUp($0) }
    }

    func sendReturn() {
        sendKey(.return)
    }
}

// MARK: - VNCConnectionDelegate

extension VNCSession: VNCConnectionDelegate {
    func connection(_ connection: VNCConnection,
                    stateDidChange connectionState: VNCConnection.ConnectionState) {
        DispatchQueue.main.async {
            AppLog.session.info("VNC connection state changed to \(String(describing: connectionState.status), privacy: .public)")

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

                if let error = connectionState.error {
                    AppLog.session.error("VNC disconnected with error: \(error.localizedDescription, privacy: .public)")
                } else {
                    AppLog.session.info("VNC disconnected without error")
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
                    AppLog.session.info("Scheduling reconnect after settings change")

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
        AppLog.session.info("Credential requested for authentication type \(String(describing: authenticationType), privacy: .public)")

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
            let cgImage = framebuffer.cgImage
            self.image = cgImage

            if let cgImage {
                AppLog.session.info("Created framebuffer \(cgImage.width, privacy: .public)x\(cgImage.height, privacy: .public)")
            } else {
                AppLog.session.warning("Created framebuffer without a CGImage")
            }

            // Start the trackpad cursor at the center of the screen.
            if self.cursorLocation == .zero, let image = self.image {
                self.cursorLocation = CGPoint(x: image.width / 2, y: image.height / 2)
            }
        }
    }

    func connection(_ connection: VNCConnection,
                    didResizeFramebuffer framebuffer: VNCFramebuffer) {
        DispatchQueue.main.async {
            let cgImage = framebuffer.cgImage
            self.image = cgImage

            if let cgImage {
                AppLog.session.info("Resized framebuffer to \(cgImage.width, privacy: .public)x\(cgImage.height, privacy: .public)")
            } else {
                AppLog.session.warning("Resized framebuffer without a CGImage")
            }
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
