import SwiftUI
import UIKit

@MainActor
final class ExternalDisplaySceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard session.role == .windowExternalDisplayNonInteractive,
              let windowScene = scene as? UIWindowScene else {
            return
        }

        let window = UIWindow(windowScene: windowScene)
        window.frame = windowScene.effectiveGeometry.coordinateSpace.bounds
        window.backgroundColor = .black
        window.rootViewController = UIHostingController(
            rootView: ExternalDisplayRootView(coordinator: .shared)
        )
        self.window = window
        AppLog.externalDisplay.info("Configured external display at \(String(describing: window.frame), privacy: .public)")
        ExternalDisplayCoordinator.shared.attachExternalWindow(window)
    }

    func windowScene(_ windowScene: UIWindowScene,
                     didUpdateEffectiveGeometry previousEffectiveGeometry: UIWindowScene.Geometry) {
        guard let window else { return }

        let screenBounds = windowScene.effectiveGeometry.coordinateSpace.bounds
        guard window.frame != screenBounds else { return }

        window.frame = screenBounds
        window.rootViewController?.view.setNeedsLayout()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        guard let window else { return }
        ExternalDisplayCoordinator.shared.detachExternalWindow(window)
        self.window = nil
    }
}
