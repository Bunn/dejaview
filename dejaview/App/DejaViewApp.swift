import SwiftUI
import OSLog
import SwiftData

@main
struct DejaViewApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(DejaViewModelContainer.shared)
        .onChange(of: scenePhase) { _, newPhase in
            AppLog.app.info("Scene phase changed to \(String(describing: newPhase), privacy: .public)")
        }
    }
}
