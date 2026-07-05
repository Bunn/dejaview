import AppIntents

struct ConnectSavedMachineIntent: AppIntent {
    static let title: LocalizedStringResource = "Connect to Mac"
    static let description = IntentDescription("Open DejaView and connect to a saved Mac.")
    static let openAppWhenRun = true

    @Parameter(title: "Mac")
    var machine: SavedMachineEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Connect to \(\.$machine)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        AppIntentRouter.shared.requestConnection(to: machine.id)
        return .result(dialog: "Connecting to \(machine.displayName).")
    }
}

struct DejaViewShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: ConnectSavedMachineIntent(),
                    phrases: [
                        "Connect to a Mac with \(.applicationName)",
                        "Start a remote session with \(.applicationName)",
                        "Open a saved Mac with \(.applicationName)"
                    ],
                    shortTitle: "Connect",
                    systemImageName: "rectangle.connected.to.line.below")
        AppShortcut(intent: OpenDejaViewIntent(),
                    phrases: [
                        "Open \(.applicationName)",
                        "Show hosts in \(.applicationName)"
                    ],
                    shortTitle: "Open",
                    systemImageName: "macwindow")
        AppShortcut(intent: RefreshNearbyMacsIntent(),
                    phrases: [
                        "Refresh nearby Macs in \(.applicationName)",
                        "Find nearby Macs with \(.applicationName)"
                    ],
                    shortTitle: "Refresh Nearby",
                    systemImageName: "arrow.clockwise")
        AppShortcut(intent: AddSavedMachineIntent(),
                    phrases: [
                        "Add a Mac to \(.applicationName)",
                        "Save a Mac in \(.applicationName)"
                    ],
                    shortTitle: "Add Mac",
                    systemImageName: "plus")
        AppShortcut(intent: DisconnectRemoteSessionIntent(),
                    phrases: [
                        "Disconnect \(.applicationName)",
                        "End remote session in \(.applicationName)"
                    ],
                    shortTitle: "Disconnect",
                    systemImageName: "xmark.circle")
    }
}
