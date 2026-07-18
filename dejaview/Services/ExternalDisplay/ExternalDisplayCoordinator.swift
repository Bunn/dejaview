import Observation
import OSLog
import UIKit

@MainActor
@Observable
final class ExternalDisplayCoordinator {
    static let shared = ExternalDisplayCoordinator()

    private(set) var isExternalDisplayAvailable = false
    private(set) var isControllerModeEnabled = false
    private(set) var activeSession: VNCSession?
    private(set) var sessionTitle = "Remote Mac"

    @ObservationIgnored private weak var externalWindow: UIWindow?

    private init() {}

    func attachExternalWindow(_ window: UIWindow) {
        externalWindow = window
        isExternalDisplayAvailable = true
        updateExternalWindowVisibility()
        AppLog.externalDisplay.info("External display scene connected")
    }

    func detachExternalWindow(_ window: UIWindow) {
        guard externalWindow === window else { return }

        externalWindow = nil
        isExternalDisplayAvailable = false
        disableControllerMode()
        AppLog.externalDisplay.info("External display scene disconnected")
    }

    func setControllerModeEnabled(_ isEnabled: Bool,
                                  for session: VNCSession,
                                  title: String) {
        guard isEnabled else {
            if activeSession === session {
                disableControllerMode()
            }
            return
        }

        guard isExternalDisplayAvailable else {
            AppLog.externalDisplay.info("Ignored controller mode request because no external display is available")
            return
        }

        activeSession = session
        sessionTitle = title
        isControllerModeEnabled = true
        updateExternalWindowVisibility()
        AppLog.externalDisplay.info("External display controller mode enabled; sessionTitle='\(title, privacy: .public)'")
    }

    func deactivate(session: VNCSession) {
        guard activeSession === session else { return }
        disableControllerMode()
    }

    func isControllerModeEnabled(for session: VNCSession) -> Bool {
        isControllerModeEnabled && activeSession === session
    }

    private func disableControllerMode() {
        let wasEnabled = isControllerModeEnabled
        isControllerModeEnabled = false
        activeSession = nil
        sessionTitle = "Remote Mac"
        updateExternalWindowVisibility()

        if wasEnabled {
            AppLog.externalDisplay.info("External display controller mode disabled")
        }
    }

    private func updateExternalWindowVisibility() {
        guard let externalWindow else { return }

        let shouldShowWindow = isControllerModeEnabled && activeSession != nil
        externalWindow.isHidden = !shouldShowWindow

        if shouldShowWindow {
            externalWindow.makeKeyAndVisible()
        }
    }
}
