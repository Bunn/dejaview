import AppIntents
import Foundation

enum DejaViewDestination: String, CaseIterable, AppEnum {
    case hosts
    case nearby

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "DejaView Section")

    static let caseDisplayRepresentations: [DejaViewDestination: DisplayRepresentation] = [
        .hosts: DisplayRepresentation(title: "Hosts", subtitle: "Saved and discovered screen sharing targets"),
        .nearby: DisplayRepresentation(title: "Nearby Macs", subtitle: "Macs advertising Screen Sharing")
    ]

    var displayName: String {
        switch self {
        case .hosts:
            "Hosts"
        case .nearby:
            "Nearby Macs"
        }
    }
}

struct OpenDejaViewIntent: AppIntent {
    static let title: LocalizedStringResource = "Open DejaView"
    static let description = IntentDescription("Open DejaView to a selected section.")
    static let openAppWhenRun = true

    @Parameter(title: "Section", default: .hosts)
    var destination: DejaViewDestination

    static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$destination)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        AppIntentRouter.shared.requestOpen(destination: destination)
        return .result(dialog: "Opening \(destination.displayName).")
    }
}

struct RefreshNearbyMacsIntent: AppIntent {
    static let title: LocalizedStringResource = "Refresh Nearby Macs"
    static let description = IntentDescription("Open DejaView and refresh nearby Screen Sharing hosts.")
    static let openAppWhenRun = true

    static var parameterSummary: some ParameterSummary {
        Summary("Refresh nearby Macs")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        AppIntentRouter.shared.requestRefreshNearby()
        return .result(dialog: "Refreshing nearby Macs.")
    }
}

struct AddSavedMachineIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Saved Mac"
    static let description = IntentDescription("Save a Mac for future DejaView connections.")
    static let openAppWhenRun = false

    @Parameter(title: "Host")
    var host: String

    @Parameter(title: "Port", default: 5900)
    var port: Int

    @Parameter(title: "Name")
    var name: String?

    @Parameter(title: "Username")
    var username: String?

    @Parameter(title: "Password")
    var password: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$host)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedHost.isEmpty else {
            throw DejaViewIntentError.missingHost
        }

        guard (1...65535).contains(port) else {
            throw DejaViewIntentError.invalidPort(port)
        }

        let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedUsername = username?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let machine = SavedMachine(name: trimmedName.isEmpty ? trimmedHost : trimmedName,
                                   host: trimmedHost,
                                   port: UInt16(port),
                                   username: trimmedUsername)

        MachineStore().add(machine, password: password ?? "")

        await MainActor.run {
            AppIntentRouter.shared.requestMachinesReload()
        }

        return .result(dialog: "Saved \(machine.displayName).")
    }
}

struct DisconnectRemoteSessionIntent: AppIntent {
    static let title: LocalizedStringResource = "Disconnect Remote Session"
    static let description = IntentDescription("Disconnect the current DejaView remote session.")
    static let openAppWhenRun = true

    static var parameterSummary: some ParameterSummary {
        Summary("Disconnect remote session")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        AppIntentRouter.shared.requestDisconnect()
        return .result(dialog: "Disconnecting remote session.")
    }
}

private enum DejaViewIntentError: LocalizedError {
    case missingHost
    case invalidPort(Int)

    var errorDescription: String? {
        switch self {
        case .missingHost:
            "Host is required."
        case .invalidPort(let port):
            "Port \(port) is invalid. Use a value from 1 to 65535."
        }
    }
}
