import Foundation

@MainActor
final class AppIntentRouter: ObservableObject, AppIntentRouting {
    static let shared = AppIntentRouter()

    @Published private(set) var request: AppIntentRequest?

    private init() {}

    func requestConnection(to machineID: UUID) {
        AppLog.ui.info("Received App Intent connection request for machine id=\(machineID.uuidString, privacy: .public)")
        request = AppIntentRequest(action: .connect(machineID: machineID))
    }

    func requestOpen(destination: DejaViewDestination) {
        AppLog.ui.info("Received App Intent open request for destination=\(destination.displayName, privacy: .public)")
        request = AppIntentRequest(action: .open(destination: destination))
    }

    func requestRefreshNearby() {
        AppLog.ui.info("Received App Intent nearby refresh request")
        request = AppIntentRequest(action: .refreshNearby)
    }

    func requestDisconnect() {
        AppLog.ui.info("Received App Intent disconnect request")
        request = AppIntentRequest(action: .disconnect)
    }

    func requestMachinesReload() {
        AppLog.ui.info("Received App Intent machine reload request")
        request = AppIntentRequest(action: .reloadMachines)
    }

    func clear(_ handledRequest: AppIntentRequest) {
        guard request == handledRequest else { return }
        request = nil
    }
}
