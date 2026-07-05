import Combine
import CoreGraphics
import RoyalVNCKit

protocol RemoteSessionInputControlling: AnyObject {
    var touchMode: RemoteTouchMode { get }
    var cursorLocation: CGPoint { get }

    func leftButtonDown(at point: CGPoint)
    func leftButtonUp(at point: CGPoint)
    func moveCursor(by delta: CGPoint, dragging: Bool)
    func moveCursor(to point: CGPoint, dragging: Bool)
    func clickAtCursor()
    func rightClick(at point: CGPoint)
    func rightClickAtCursor()
    func scroll(_ direction: RemoteScrollDirection, steps: UInt32)
    func pressAtCursor()
    func releaseAtCursor()
    func sendText(_ text: String, modifiers: [VNCKeyCode])
    func sendKey(_ keyCode: VNCKeyCode, modifiers: [VNCKeyCode])
    func sendReturn()
}

protocol RemoteSessionControlling: ObservableObject, RemoteSessionInputControlling {
    var status: RemoteSessionStatus { get }
    var image: CGImage? { get }
    var quality: RemoteSessionQuality { get }
    var isClipboardSyncEnabled: Bool { get }

    func connect(host: String, port: UInt16, username: String, password: String)
    func disconnect()
    func reset()
    func setQuality(_ newQuality: RemoteSessionQuality)
    func toggleClipboardSync()
    func toggleTouchMode()
    func retryConnect()
}

extension RemoteSessionInputControlling {
    func moveCursor(to point: CGPoint) {
        moveCursor(to: point, dragging: false)
    }

    func scroll(_ direction: RemoteScrollDirection) {
        scroll(direction, steps: 1)
    }

    func sendText(_ text: String) {
        sendText(text, modifiers: [])
    }

    func sendKey(_ keyCode: VNCKeyCode) {
        sendKey(keyCode, modifiers: [])
    }
}
