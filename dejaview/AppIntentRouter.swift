import Foundation

@MainActor
final class AppIntentRouter: ObservableObject {
    struct Request: Equatable, Identifiable {
        let id = UUID()
        let action: Action
    }

    enum Action: Equatable {
        case connect(machineID: UUID)
        case open(destination: DejaViewDestination)
        case refreshNearby
        case disconnect
        case reloadMachines
    }

    static let shared = AppIntentRouter()

    @Published private(set) var request: Request?

    private init() {}

    func requestConnection(to machineID: UUID) {
        AppLog.ui.info("Received App Intent connection request for machine id=\(machineID.uuidString, privacy: .public)")
        request = Request(action: .connect(machineID: machineID))
    }

    func requestOpen(destination: DejaViewDestination) {
        AppLog.ui.info("Received App Intent open request for destination=\(destination.displayName, privacy: .public)")
        request = Request(action: .open(destination: destination))
    }

    func requestRefreshNearby() {
        AppLog.ui.info("Received App Intent nearby refresh request")
        request = Request(action: .refreshNearby)
    }

    func requestDisconnect() {
        AppLog.ui.info("Received App Intent disconnect request")
        request = Request(action: .disconnect)
    }

    func requestMachinesReload() {
        AppLog.ui.info("Received App Intent machine reload request")
        request = Request(action: .reloadMachines)
    }

    func clear(_ handledRequest: Request) {
        guard request == handledRequest else { return }
        request = nil
    }
}
