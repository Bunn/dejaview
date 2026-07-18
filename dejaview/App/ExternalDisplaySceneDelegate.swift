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
        window.backgroundColor = .black
        window.rootViewController = UIHostingController(
            rootView: ExternalDisplayRootView(coordinator: .shared)
        )
        self.window = window
        ExternalDisplayCoordinator.shared.attachExternalWindow(window)
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        guard let window else { return }
        ExternalDisplayCoordinator.shared.detachExternalWindow(window)
        self.window = nil
    }
}
