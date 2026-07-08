import Combine
import Foundation
import CoreGraphics
import OSLog
import RoyalVNCKit

/// Owns the `VNCConnection`, implements its delegate, and publishes
/// connection state + framebuffer images for SwiftUI to observe.
/// RoyalVNCKit delegate callbacks are bridged back to the main actor before
/// mutating session state.
final class VNCSession: NSObject, ObservableObject, RemoteSessionControlling, @unchecked Sendable {
    @Published var status: RemoteSessionStatus = .idle
    @Published private(set) var quality: RemoteSessionQuality = .best
    @Published private(set) var isClipboardSyncEnabled = false
    @Published private(set) var touchMode: RemoteTouchMode = .direct
    @Published private(set) var displays: [RemoteDisplay] = []
    @Published private(set) var displaySelection: RemoteDisplaySelection = .all

    /// Current framebuffer, published outside `objectWillChange` so that
    /// per-frame updates don't invalidate SwiftUI (see the protocol note).
    private let imageSubject = CurrentValueSubject<CGImage?, Never>(nil)
    private let framebufferUpdateSubject = CurrentValueSubject<RemoteFramebufferUpdate, Never>(.empty)
    private let cursorSubject = CurrentValueSubject<RemoteCursor?, Never>(nil)
    private var currentImage: CGImage?

    var image: CGImage? {
        currentImage
    }

    var imagePublisher: AnyPublisher<CGImage?, Never> {
        imageSubject.eraseToAnyPublisher()
    }

    var framebufferUpdatePublisher: AnyPublisher<RemoteFramebufferUpdate, Never> {
        framebufferUpdateSubject.eraseToAnyPublisher()
    }

    var cursor: RemoteCursor? {
        get { cursorSubject.value }
        set { cursorSubject.send(newValue) }
    }

    var cursorPublisher: AnyPublisher<RemoteCursor?, Never> {
        cursorSubject.eraseToAnyPublisher()
    }

    var displayOptions: [RemoteDisplayOption] {
        Self.displayOptions(for: displays, framebufferFrame: framebufferFrameForDisplaySelection)
    }

    var selectedDisplayFrame: CGRect? {
        switch displaySelection {
        case .all:
            return nil
        case .display(let id):
            return displays.first { $0.id == id }?.frame
        case .region(let region):
            guard let framebufferFrame = framebufferFrameForDisplaySelection else { return nil }

            return region.frame(in: framebufferFrame)
        }
    }

    /// Last known remote cursor position (framebuffer coordinates).
    private(set) var cursorLocation: CGPoint = .zero

    private(set) var connection: VNCConnection?

    private var host = ""
    private var port: UInt16 = 5900
    private var username = ""
    private var password = ""
    private var reconnectPending = false
    private var heldModifierKeys: Set<RemoteModifierKey> = []
    private static let combinedFramebufferAspectRatioThreshold: CGFloat = 2.4

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
            colorDepth: .depth24Bit,
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
        releaseHeldModifiers()
        connection?.disconnect()
    }

    /// Returns the session to a clean state after the session UI is dismissed.
    func reset() {
        AppLog.session.info("Resetting session state")
        reconnectPending = false
        releaseHeldModifiers()
        connection?.delegate = nil
        connection = nil
        publishFramebuffer(nil)
        cursor = nil
        displays = []
        displaySelection = .all
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

    func setDisplaySelection(_ selection: RemoteDisplaySelection) {
        let normalizedSelection = normalizedDisplaySelection(selection)
        guard normalizedSelection != displaySelection else { return }

        displaySelection = normalizedSelection
        clampCursorToSelectableBounds()

        AppLog.session.info("Display selection changed to \(self.displaySelection.logDescription, privacy: .public)")
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
        releaseHeldModifiers()
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
        let point = CGPoint(x: cursorLocation.x + delta.x,
                            y: cursorLocation.y + delta.y)

        moveCursor(to: point, dragging: dragging)
    }

    func moveCursor(to point: CGPoint, dragging: Bool = false) {
        guard image != nil else { return }

        let clamped = clampedCursorPoint(point)

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
        let clamped = clampedCursorPoint(point)

        AppLog.input.debug("Right click at x=\(clamped.x, privacy: .public) y=\(clamped.y, privacy: .public)")
        cursorLocation = clamped

        let x = UInt16(clamping: Int(clamped.x))
        let y = UInt16(clamping: Int(clamped.y))

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

    // MARK: - Held keyboard modifiers

    func setModifier(_ modifier: RemoteModifierKey, isPressed: Bool) {
        let isCurrentlyPressed = heldModifierKeys.contains(modifier)
        guard isPressed != isCurrentlyPressed else { return }

        if isPressed {
            heldModifierKeys.insert(modifier)
            connection?.keyDown(modifier.keyCode)
        } else {
            heldModifierKeys.remove(modifier)
            connection?.keyUp(modifier.keyCode)
        }

        AppLog.input.debug("Remote modifier changed; modifier=\(modifier.rawValue, privacy: .public) pressed=\(isPressed, privacy: .public)")
    }

    func releaseHeldModifiers() {
        guard !heldModifierKeys.isEmpty else { return }

        for modifier in RemoteModifierKey.allCases.reversed() where heldModifierKeys.contains(modifier) {
            connection?.keyUp(modifier.keyCode)
        }

        heldModifierKeys.removeAll()
        AppLog.input.debug("Released held remote modifiers")
    }

    // MARK: - Keyboard input

    func sendText(_ text: String, modifiers: [VNCKeyCode] = []) {
        guard let connection else { return }

        AppLog.input.debug("Sending text to remote; characterCount=\(text.count, privacy: .public) modifiers=\(modifiers.count, privacy: .public)")
        let transientModifiers = transientModifiers(from: modifiers)
        transientModifiers.forEach { connection.keyDown($0) }

        for keyCode in VNCKeyCode.keyCodesFrom(characters: text) {
            connection.keyDown(keyCode)
            connection.keyUp(keyCode)
        }

        transientModifiers.reversed().forEach { connection.keyUp($0) }
    }

    func sendKey(_ keyCode: VNCKeyCode, modifiers: [VNCKeyCode] = []) {
        guard let connection else { return }

        AppLog.input.debug("Sending key to remote; key=\(String(describing: keyCode), privacy: .public) modifiers=\(modifiers.count, privacy: .public)")
        let transientModifiers = transientModifiers(from: modifiers)
        transientModifiers.forEach { connection.keyDown($0) }
        connection.keyDown(keyCode)
        connection.keyUp(keyCode)
        transientModifiers.reversed().forEach { connection.keyUp($0) }
    }

    func sendReturn() {
        sendKey(.return)
    }

    private func transientModifiers(from modifiers: [VNCKeyCode]) -> [VNCKeyCode] {
        let heldModifierRawValues = Set(heldModifierKeys.map(\.keyCode.rawValue))

        return modifiers.filter { !heldModifierRawValues.contains($0.rawValue) }
    }

    private func publishFramebuffer(_ image: CGImage?, dirtyRect: CGRect? = nil) {
        currentImage = image

        if dirtyRect == nil {
            imageSubject.send(image)
        }

        framebufferUpdateSubject.send(RemoteFramebufferUpdate(image: image,
                                                              dirtyRect: dirtyRect))
    }

    // MARK: - Display selection

    private var framebufferFrameForDisplaySelection: CGRect? {
        if let image {
            return CGRect(x: 0,
                          y: 0,
                          width: image.width,
                          height: image.height)
        }

        if displays.count == 1 {
            return displays[0].frame
        }

        return nil
    }

    private func updateDisplays(_ newDisplays: [RemoteDisplay]) {
        let previousCount = displays.count
        let previousSelection = displaySelection
        displays = newDisplays
        displaySelection = normalizedDisplaySelection(displaySelection)
        clampCursorToSelectableBounds()

        let layoutDescription = Self.displayLayoutDescription(newDisplays)
        let optionDescription = displayOptions.map(\.logDescription).joined(separator: "; ")
        AppLog.session.info("Remote display layout updated; previousCount=\(previousCount, privacy: .public) count=\(newDisplays.count, privacy: .public) selectionBefore=\(previousSelection.logDescription, privacy: .public) selectionAfter=\(self.displaySelection.logDescription, privacy: .public) optionCount=\(self.displayOptions.count, privacy: .public) options=\(optionDescription, privacy: .public) layout=\(layoutDescription, privacy: .public)")

        if newDisplays.count <= 1 {
            AppLog.session.warning("VNC server reported \(newDisplays.count, privacy: .public) screen(s). If the remote Mac has multiple physical displays, it is exposing them as one combined framebuffer or not exposing extended desktop metadata.")
        }
    }

    private static func remoteDisplays(from screens: [VNCScreen]) -> [RemoteDisplay] {
        screens
            .sorted {
                if $0.cgFrame.minY == $1.cgFrame.minY {
                    $0.cgFrame.minX < $1.cgFrame.minX
                } else {
                    $0.cgFrame.minY < $1.cgFrame.minY
                }
            }
            .enumerated()
            .map { index, screen in
                RemoteDisplay(id: screen.id,
                              name: "Display \(index + 1)",
                              frame: screen.cgFrame)
            }
    }

    private static func displayOptions(for displays: [RemoteDisplay],
                                       framebufferFrame: CGRect?) -> [RemoteDisplayOption] {
        var options = [
            RemoteDisplayOption(selection: .all,
                                title: "All Displays",
                                systemImage: "rectangle.split.2x1")
        ]

        if displays.count > 1 {
            options.append(contentsOf: displays.map { display in
                RemoteDisplayOption(selection: .display(display.id),
                                    title: display.menuTitle,
                                    systemImage: "display")
            })
        } else if let framebufferFrame {
            options.append(contentsOf: fallbackDisplayRegions(for: framebufferFrame).map { region in
                RemoteDisplayOption(selection: .region(region),
                                    title: region.title,
                                    systemImage: region.systemImage)
            })
        }

        return options
    }

    private static func fallbackDisplayRegions(for framebufferFrame: CGRect) -> [RemoteDisplayRegion] {
        guard framebufferFrame.width > 0, framebufferFrame.height > 0 else { return [] }

        let aspectRatio = framebufferFrame.width / framebufferFrame.height

        if aspectRatio >= combinedFramebufferAspectRatioThreshold {
            return [.left, .right]
        } else if aspectRatio <= 1 / combinedFramebufferAspectRatioThreshold {
            return [.top, .bottom]
        } else {
            return []
        }
    }

    private static func displayLayoutDescription(_ displays: [RemoteDisplay]) -> String {
        guard !displays.isEmpty else { return "none" }

        return displays.map(\.logDescription).joined(separator: "; ")
    }

    private static func screenLayoutDescription(from screens: [VNCScreen]) -> String {
        guard !screens.isEmpty else { return "none" }

        return screens
            .sorted {
                if $0.cgFrame.minY == $1.cgFrame.minY {
                    $0.cgFrame.minX < $1.cgFrame.minX
                } else {
                    $0.cgFrame.minY < $1.cgFrame.minY
                }
            }
            .map { screen in
                let frame = screen.cgFrame
                let minX = Int(frame.minX.rounded())
                let minY = Int(frame.minY.rounded())
                let width = Int(frame.width.rounded())
                let height = Int(frame.height.rounded())

                return "id=\(screen.id) frame=(x:\(minX),y:\(minY),w:\(width),h:\(height))"
            }
            .joined(separator: "; ")
    }

    private func normalizedDisplaySelection(_ selection: RemoteDisplaySelection) -> RemoteDisplaySelection {
        switch selection {
        case .all:
            return .all
        case .display(let id):
            if displays.count > 1, displays.contains(where: { $0.id == id }) {
                return selection
            } else {
                let availableIDs = displays.map { String($0.id) }.joined(separator: ",")
                AppLog.session.warning("Display selection normalized to all; reason=missingDisplay requested=\(selection.logDescription, privacy: .public) availableDisplayIDs=\(availableIDs, privacy: .public)")

                return .all
            }
        case .region(let region):
            guard displays.count <= 1,
                  let framebufferFrame = framebufferFrameForDisplaySelection,
                  Self.fallbackDisplayRegions(for: framebufferFrame).contains(region) else {
                AppLog.session.warning("Display selection normalized to all; reason=invalidRegion requested=\(selection.logDescription, privacy: .public) reportedDisplayCount=\(self.displays.count, privacy: .public)")

                return .all
            }

            return selection
        }
    }

    private var selectableCursorBounds: CGRect? {
        guard let image else { return nil }

        let framebufferBounds = CGRect(x: 0,
                                       y: 0,
                                       width: image.width,
                                       height: image.height)

        guard let selectedDisplayFrame else { return framebufferBounds }

        let displayBounds = selectedDisplayFrame.intersection(framebufferBounds)

        return displayBounds.isNull ? framebufferBounds : displayBounds
    }

    private func clampedCursorPoint(_ point: CGPoint) -> CGPoint {
        guard let bounds = selectableCursorBounds else { return point }

        return CGPoint(x: min(max(point.x, bounds.minX), bounds.maxX),
                       y: min(max(point.y, bounds.minY), bounds.maxY))
    }

    private func clampCursorToSelectableBounds() {
        cursorLocation = clampedCursorPoint(cursorLocation)
    }
}

// MARK: - VNCConnectionDelegate

extension VNCSession: VNCConnectionDelegate {
    func connection(_ connection: VNCConnection,
                    stateDidChange connectionState: VNCConnection.ConnectionState) {
        let status = connectionState.status
        let userFacingMessage: String?

        if let error = connectionState.error as? VNCError,
           error.shouldDisplayToUser {
            userFacingMessage = error.localizedDescription
        } else {
            userFacingMessage = nil
        }

        let errorDescription = connectionState.error?.localizedDescription

        Task { @MainActor [weak self] in
            guard let self else { return }

            AppLog.session.info("VNC connection state changed to \(String(describing: status), privacy: .public)")

            switch status {
            case .connecting:
                self.status = .connecting
            case .connected:
                self.status = .connected
            case .disconnected:
                if let errorDescription {
                    AppLog.session.error("VNC disconnected with error: \(errorDescription, privacy: .public)")
                } else {
                    AppLog.session.info("VNC disconnected without error")
                }

                self.connection?.delegate = nil
                self.releaseHeldModifiers()
                self.connection = nil
                self.publishFramebuffer(nil)
                self.cursor = nil

                if self.reconnectPending {
                    // Settings changed mid-session: reconnect with new settings.
                    // Wait for macOS's Screen Sharing daemon to release the old
                    // session first — reconnecting instantly gets the new
                    // connection reset (and rapid retries can make the Mac
                    // refuse connections for a while).
                    self.reconnectPending = false
                    self.status = .connecting
                    AppLog.session.info("Scheduling reconnect after settings change")

                    Task { @MainActor [weak self] in
                        try? await Task.sleep(for: .seconds(2))
                        guard let self else { return }
                        // Bail if the user dismissed the session meanwhile.
                        guard self.status == .connecting, self.connection == nil else { return }

                        self.connect(host: self.host,
                                     port: self.port,
                                     username: self.username,
                                     password: self.password)
                    }
                } else {
                    self.status = .disconnected(userFacingMessage)
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
        let cgImage = framebuffer.cgImage
        let screens = framebuffer.screens
        let displays = Self.remoteDisplays(from: screens)
        let screenCount = screens.count
        let screenLayout = Self.screenLayoutDescription(from: screens)

        Task { @MainActor [weak self] in
            guard let self else { return }

            self.publishFramebuffer(cgImage)
            self.updateDisplays(displays)

            if let cgImage {
                AppLog.session.info("Created framebuffer width=\(cgImage.width, privacy: .public) height=\(cgImage.height, privacy: .public) vncScreenCount=\(screenCount, privacy: .public) vncScreens=\(screenLayout, privacy: .public)")
            } else {
                AppLog.session.warning("Created framebuffer without a CGImage; vncScreenCount=\(screenCount, privacy: .public) vncScreens=\(screenLayout, privacy: .public)")
            }

            // Start the trackpad cursor at the center of the screen.
            if self.cursorLocation == .zero, let image = self.image {
                self.cursorLocation = CGPoint(x: image.width / 2, y: image.height / 2)
            }
        }
    }

    func connection(_ connection: VNCConnection,
                    didResizeFramebuffer framebuffer: VNCFramebuffer) {
        let cgImage = framebuffer.cgImage
        let screens = framebuffer.screens
        let displays = Self.remoteDisplays(from: screens)
        let screenCount = screens.count
        let screenLayout = Self.screenLayoutDescription(from: screens)

        Task { @MainActor [weak self] in
            guard let self else { return }

            self.publishFramebuffer(cgImage)
            self.updateDisplays(displays)

            if let cgImage {
                AppLog.session.info("Resized framebuffer width=\(cgImage.width, privacy: .public) height=\(cgImage.height, privacy: .public) vncScreenCount=\(screenCount, privacy: .public) vncScreens=\(screenLayout, privacy: .public)")
            } else {
                AppLog.session.warning("Resized framebuffer without a CGImage; vncScreenCount=\(screenCount, privacy: .public) vncScreens=\(screenLayout, privacy: .public)")
            }
        }
    }

    func connection(_ connection: VNCConnection,
                    didUpdateFramebuffer framebuffer: VNCFramebuffer,
                    x: UInt16, y: UInt16,
                    width: UInt16, height: UInt16) {
        let cgImage = framebuffer.cgImage
        let dirtyRect = CGRect(x: CGFloat(x),
                               y: CGFloat(y),
                               width: CGFloat(width),
                               height: CGFloat(height))

        Task { @MainActor [weak self] in
            self?.publishFramebuffer(cgImage, dirtyRect: dirtyRect)
        }
    }

    func connection(_ connection: VNCConnection,
                    didUpdateCursor cursor: VNCCursor) {
        let remoteCursor: RemoteCursor?

        if cursor.isEmpty {
            remoteCursor = nil
        } else if let image = cursor.cgImage {
            remoteCursor = RemoteCursor(image: image,
                                        hotspot: cursor.cgHotspot,
                                        size: cursor.cgSize)
        } else {
            remoteCursor = nil
        }

        Task { @MainActor [weak self] in
            self?.cursor = remoteCursor
        }
    }
}
