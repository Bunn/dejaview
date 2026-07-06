import SwiftUI
import OSLog
import SwiftData

@main
struct DejaViewApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var subscriptionStore = SubscriptionStore()

    init() {
        RevenueCatConfiguration.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(subscriptionStore)
                .task {
                    await subscriptionStore.refresh()
                    await subscriptionStore.observeCustomerInfoUpdates()
                }
        }
        .modelContainer(DejaViewModelContainer.shared)
        .onChange(of: scenePhase) { _, newPhase in
            AppLog.app.info("Scene phase changed to \(String(describing: newPhase), privacy: .public)")
        }
    }
}
