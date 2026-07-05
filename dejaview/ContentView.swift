import SwiftUI
import OSLog

struct ContentView: View {
    @StateObject private var session = VNCSession()
    @StateObject private var browser = BonjourBrowser()
    @StateObject private var store = MachineStore()
    @StateObject private var intentRouter = AppIntentRouter.shared

    @State private var selectedSection: ConnectSection? = .hosts
    @State private var searchText = ""

    @State private var isSessionPresented = false

    @State private var editingMachine: SavedMachine?
    @State private var editingPassword = ""
    @State private var pendingConnectionMachine: SavedMachine?
    @State private var pendingConnectionPassword = ""

    private static let appleScreenSharingHelpURL = URL(string: "https://support.apple.com/guide/mac-help/turn-screen-sharing-on-or-off-mh11848/mac")!

    var body: some View {
        NavigationSplitView {
            ConnectSidebarView(selection: $selectedSection,
                               hostCount: store.machines.count + browser.services.count,
                               nearbyCount: browser.services.count)
        } detail: {
            detailView
                .navigationTitle(currentSection.title)
                .navigationBarTitleDisplayMode(.inline)
                .searchable(text: $searchText,
                            placement: .navigationBarDrawer(displayMode: .always),
                            prompt: "Search")
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button("Add Host", systemImage: "plus", action: addMachine)

                        Menu("More", systemImage: "ellipsis.circle") {
                            Button("Refresh Nearby Macs", systemImage: "arrow.clockwise", action: refreshNearbyMacs)
                        }
                    }
                }
        }
        .navigationSplitViewStyle(.balanced)
        .fullScreenCover(isPresented: $isSessionPresented, onDismiss: session.reset) {
            SessionView(session: session)
        }
        .sheet(item: $editingMachine, onDismiss: connectPendingMachine) { machine in
            EditMachineView(store: store,
                            machine: machine,
                            password: editingPassword,
                            connectWithoutSaving: queueDirectConnection)
        }
        .onAppear {
            AppLog.ui.info("Connect view appeared; starting nearby Mac discovery")
            browser.start()
            handlePendingIntentRequest()
        }
        .onChange(of: intentRouter.request) { _, request in
            guard let request else { return }
            handleIntentRequest(request)
        }
    }

    // MARK: - Detail

    private var currentSection: ConnectSection {
        selectedSection ?? .hosts
    }

    private var detailView: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            ScrollView {
                detailContentStack
            }
        }
    }

    private var detailContentStack: some View {
        VStack(alignment: .leading, spacing: 24) {
            ConnectHeaderView(section: currentSection)

            switch currentSection {
            case .hosts:
                hostsContent
            case .nearby:
                nearbyContent
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(maxWidth: 1280, alignment: .leading)
    }

    @ViewBuilder
    private var hostsContent: some View {
        if filteredMachines.isEmpty && filteredServices.isEmpty {
            unavailableHostsView
        } else {
            hostGrid
        }

        manualPanel
    }

    @ViewBuilder
    private var nearbyContent: some View {
        if filteredServices.isEmpty {
            if isSearching {
                ContentUnavailableView.search
            } else {
                scanningPanel
            }
        } else {
            nearbyGrid
        }
    }

    @ViewBuilder
    private var hostGrid: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 16) {
                hostGridContent
            }
        } else {
            hostGridContent
        }
    }

    private var hostGridContent: some View {
        LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 16) {
            ForEach(filteredMachines) { machine in
                SavedMachineTile(machine: machine) {
                    connect(to: machine)
                } edit: {
                    edit(machine)
                }
            }

            ForEach(filteredServices) { service in
                DiscoveredServiceTile(service: service) {
                    addMachine(for: service)
                }
            }
        }
    }

    @ViewBuilder
    private var nearbyGrid: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 16) {
                nearbyGridContent
            }
        } else {
            nearbyGridContent
        }
    }

    private var nearbyGridContent: some View {
        LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 16) {
            ForEach(filteredServices) { service in
                DiscoveredServiceTile(service: service) {
                    addMachine(for: service)
                }
            }
        }
    }

    private var scanningPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                ProgressView()

                VStack(alignment: .leading, spacing: 3) {
                    Text("Looking for Macs")
                        .font(.headline)

                    Text("Screen Sharing hosts appear here automatically.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Link(destination: Self.appleScreenSharingHelpURL) {
                Label("Not seeing your Mac?", systemImage: "questionmark.circle")
            }
            .glassButtonStyle()
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .glassPanel(cornerRadius: 28)
    }

    @ViewBuilder
    private var unavailableHostsView: some View {
        if isSearching {
            ContentUnavailableView.search
        } else {
            ContentUnavailableView("No Hosts",
                                   systemImage: "rectangle.connected.to.line.below",
                                   description: Text("Add a host, discover one nearby, or connect manually."))
                .padding(24)
                .frame(maxWidth: .infinity)
                .glassPanel(cornerRadius: 28)
        }
    }

    private var manualPanel: some View {
        Button("New Machine", systemImage: "plus", action: addMachine)
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 52)
            .prominentGlassButtonStyle()
    }

    private var gridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 300), spacing: 16, alignment: .top)]
    }

    private var filteredMachines: [SavedMachine] {
        guard isSearching else { return store.machines }

        return store.machines.filter { machine in
            machine.displayName.localizedCaseInsensitiveContains(searchQuery) ||
            machine.subtitle.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    private var filteredServices: [DiscoveredService] {
        guard isSearching else { return browser.services }

        return browser.services.filter { service in
            service.name.localizedCaseInsensitiveContains(searchQuery) ||
            service.host?.localizedCaseInsensitiveContains(searchQuery) == true
        }
    }

    private var isSearching: Bool {
        !searchQuery.isEmpty
    }

    private var searchQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Actions

    private func addMachine() {
        AppLog.ui.info("Opening New Machine sheet")
        editingPassword = ""
        editingMachine = SavedMachine(name: "", host: "", username: "")
    }

    private func addMachine(for service: DiscoveredService) {
        guard let serviceHost = service.host, let servicePort = service.port else {
            AppLog.ui.warning("Ignored unresolved nearby service '\(service.name, privacy: .public)'")
            return
        }

        AppLog.ui.info("Opening New Machine sheet from nearby service '\(service.name, privacy: .public)' at \(serviceHost, privacy: .public):\(servicePort, privacy: .public)")
        editingPassword = ""
        editingMachine = SavedMachine(name: service.name,
                                      host: serviceHost,
                                      port: servicePort,
                                      username: "")
    }

    private func edit(_ machine: SavedMachine) {
        AppLog.ui.info("Opening Edit Machine sheet for '\(machine.displayName, privacy: .public)'")
        editingPassword = store.password(for: machine)
        editingMachine = machine
    }

    private func refreshNearbyMacs() {
        AppLog.ui.info("Refreshing nearby Mac discovery")
        browser.stop()
        browser.start()
    }

    private func queueDirectConnection(machine: SavedMachine, password: String) {
        AppLog.ui.info("Queued direct connection without saving for \(machine.host, privacy: .public):\(machine.port, privacy: .public)")
        pendingConnectionMachine = machine
        pendingConnectionPassword = password
    }

    private func connectPendingMachine() {
        guard let machine = pendingConnectionMachine else { return }

        AppLog.ui.info("Starting pending direct connection to \(machine.host, privacy: .public):\(machine.port, privacy: .public)")
        pendingConnectionMachine = nil
        connect(to: machine, password: pendingConnectionPassword)
        pendingConnectionPassword = ""
    }

    private func connect(to machine: SavedMachine) {
        AppLog.ui.info("Starting saved machine connection to '\(machine.displayName, privacy: .public)'")
        connect(to: machine, password: store.password(for: machine))
    }

    private func connectFromIntent(machineID: UUID) {
        guard let machine = store.machine(withID: machineID) else {
            AppLog.ui.warning("Ignored App Intent connection request for missing machine id=\(machineID.uuidString, privacy: .public)")
            return
        }

        selectedSection = .hosts
        searchText = ""
        editingMachine = nil
        connect(to: machine)
    }

    private func openFromIntent(destination: DejaViewDestination) {
        selectedSection = connectSection(for: destination)
        searchText = ""
        editingMachine = nil
    }

    private func refreshNearbyFromIntent() {
        openFromIntent(destination: .nearby)
        refreshNearbyMacs()
    }

    private func disconnectFromIntent() {
        AppLog.ui.info("Disconnecting session from App Intent")
        session.disconnect()

        if isSessionPresented {
            isSessionPresented = false
        } else {
            session.reset()
        }
    }

    private func handlePendingIntentRequest() {
        guard let request = intentRouter.request else { return }
        handleIntentRequest(request)
    }

    private func handleIntentRequest(_ request: AppIntentRouter.Request) {
        switch request.action {
        case .connect(let machineID):
            connectFromIntent(machineID: machineID)
        case .open(let destination):
            openFromIntent(destination: destination)
        case .refreshNearby:
            refreshNearbyFromIntent()
        case .disconnect:
            disconnectFromIntent()
        case .reloadMachines:
            store.reload()
        }

        intentRouter.clear(request)
    }

    private func connectSection(for destination: DejaViewDestination) -> ConnectSection {
        switch destination {
        case .hosts:
            .hosts
        case .nearby:
            .nearby
        }
    }

    private func connect(to machine: SavedMachine, password: String) {
        AppLog.ui.info("Presenting session for \(machine.host, privacy: .public):\(machine.port, privacy: .public)")
        session.connect(host: machine.host,
                        port: machine.port,
                        username: machine.username,
                        password: password)

        isSessionPresented = true
    }
}

#Preview {
    ContentView()
}
