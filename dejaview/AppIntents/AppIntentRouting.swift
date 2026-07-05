import Foundation

enum AppIntentAction: Equatable {
    case connect(machineID: UUID)
    case open(destination: DejaViewDestination)
    case refreshNearby
    case disconnect
    case reloadMachines
}

struct AppIntentRequest: Equatable, Identifiable {
    let id = UUID()
    let action: AppIntentAction
}

@MainActor
protocol AppIntentRouting: AnyObject {
    var request: AppIntentRequest? { get }

    func clear(_ handledRequest: AppIntentRequest)
}
