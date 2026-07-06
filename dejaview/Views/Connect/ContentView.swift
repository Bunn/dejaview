import SwiftUI
import OSLog

struct ContentView<Session: RemoteSessionControlling,
                   Browser: BonjourBrowsing,
                   Store: MachineStoring,
                   Router: AppIntentRouting>: View {
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var session: Session
    @State private var browser: Browser
    @State private var store: Store
    @State private var intentRouter: Router
    @State private var networkPathObserver = NetworkPathObserver()

    @State private var selectedSection: ConnectSection? = .hosts
    @State private var searchText = ""

    @State private var isSessionPresented = false
    @State private var isSettingsPresented = false

    @State private var editingMachine: SavedMachine?
    @State private var editingPassword = ""
    @State private var pendingConnectionMachine: SavedMachine?
    @State private var pendingConnectionPassword = ""
    @State private var pendingDeletionMachine: SavedMachine?
    @State private var isDeleteConfirmationPresented = false
    @State private var machineReachabilityStatuses: [UUID: MachineReachabilityStatus] = [:]
    @State private var machineReachabilityEndpoints: [UUID: String] = [:]
    @State private var reachabilityProbeGeneration = 0

    private let appleScreenSharingHelpURL = URL(string: "https://support.apple.com/guide/mac-help/turn-screen-sharing-on-or-off-mh11848/mac")!
    private let reachabilityRefreshInterval: Duration = .seconds(30)

    init(dependencies: AppDependencies<Session, Browser, Store, Router>) {
        _session = StateObject(wrappedValue: dependencies.makeSession())
        _browser = State(initialValue: dependencies.makeBrowser())
        _store = State(initialValue: dependencies.makeStore())
        _intentRouter = State(initialValue: dependencies.makeIntentRouter())
    }

    var body: some View {
        NavigationSplitView {
            ConnectSidebarView(selection: $selectedSection,
                               hostCount: store.machines.count + browser.services.count,
                               nearbyCount: browser.services.count)
        } detail: {
            detailRoot
        }
        .navigationSplitViewStyle(.balanced)
        .fullScreenCover(isPresented: $isSessionPresented, onDismiss: session.reset) {
            SessionView(session: session)
        }
        .sheet(isPresented: $isSettingsPresented) {
            NavigationStack {
                SettingsView()
                    .navigationTitle("Settings")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done", action: dismissSettings)
                        }
                    }
            }
        }
        .sheet(item: $editingMachine, onDismiss: connectPendingMachine) { machine in
            EditMachineView(store: store,
                            machine: machine,
                            password: editingPassword,
                            connectAfterDismiss: queueConnectionAfterEditor)
        }
        .alert("Delete Machine?",
               isPresented: $isDeleteConfirmationPresented,
               presenting: pendingDeletionMachine) { machine in
            Button("Delete", role: .destructive) {
                delete(machine)
            }

            Button("Cancel", role: .cancel) {
                pendingDeletionMachine = nil
            }
        } message: { machine in
            Text("This removes \(machine.displayName) from your saved machines.")
        }
        .onAppear {
            AppLog.ui.info("Connect view appeared; starting nearby Mac discovery")
            browser.start()
            networkPathObserver.start()
            handlePendingIntentRequest()
        }
        .onDisappear {
            networkPathObserver.stop()
        }
        .onChange(of: intentRouter.request) { _, request in
            guard let request else { return }
            handleIntentRequest(request)
        }
        .onChange(of: networkPathObserver.snapshot) { oldSnapshot, newSnapshot in
            guard oldSnapshot != nil, let newSnapshot else { return }

            Task {
                await refreshForNetworkPathChange(newSnapshot)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }

            Task {
                await refreshMachineList(reason: "sceneBecameActive", marksMachinesChecking: false)
            }
        }
        .task(id: machineReachabilitySignature) {
            await monitorSavedMachineReachability()
        }
    }

    // MARK: - Detail

    private var currentSection: ConnectSection {
        selectedSection ?? .hosts
    }

    private var detailView: some View {
        connectDetailView
    }

    private var detailRoot: some View {
        detailView
            .navigationTitle(currentSection.title)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search")
            .toolbar {
                detailToolbar
            }
    }

    @ToolbarContentBuilder
    private var detailToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button("Add Host", systemImage: "plus", action: addMachine)

            Menu("More", systemImage: "ellipsis.circle") {
                Button("Settings", systemImage: "gearshape", action: openSettings)
                Divider()
                Button("Refresh Machines", systemImage: "arrow.clockwise", action: refreshMachines)
            }
        }
    }

    private var connectDetailView: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            ScrollView {
                detailContentStack
            }
            .refreshable {
                await refreshMachineList(reason: "pullToRefresh", marksMachinesChecking: false)
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
        GlassEffectContainer(spacing: 16) {
            hostGridContent
        }
    }

    private var hostGridContent: some View {
        LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 16) {
            ForEach(filteredMachines) { machine in
                SavedMachineTile(machine: machine,
                                 reachabilityStatus: reachabilityStatus(for: machine)) {
                    connect(to: machine)
                } edit: {
                    edit(machine)
                } delete: {
                    confirmDelete(machine)
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
        GlassEffectContainer(spacing: 16) {
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

            Link(destination: appleScreenSharingHelpURL) {
                Label("Not seeing your Mac?", systemImage: "questionmark.circle")
            }
            .buttonStyle(.glass)
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
            .buttonStyle(.glassProminent)
    }

    private var gridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 300), spacing: 16, alignment: .top)]
    }

    private var filteredMachines: [SavedMachine] {
        guard isSearching else { return store.machines }

        return store.machines.filter { machine in
            machine.displayName.localizedStandardContains(searchQuery) ||
            machine.subtitle.localizedStandardContains(searchQuery)
        }
    }

    private var filteredServices: [DiscoveredService] {
        guard isSearching else { return browser.services }

        return browser.services.filter { service in
            service.name.localizedStandardContains(searchQuery) ||
            service.host?.localizedStandardContains(searchQuery) == true
        }
    }

    private var isSearching: Bool {
        !searchQuery.isEmpty
    }

    private var searchQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var machineReachabilitySignature: String {
        store.machines
            .map { "\($0.id.uuidString)|\(reachabilityEndpointKey(for: $0))" }
            .joined(separator: "\n")
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

    private func confirmDelete(_ machine: SavedMachine) {
        AppLog.ui.info("Showing delete confirmation for '\(machine.displayName, privacy: .public)'")
        pendingDeletionMachine = machine
        isDeleteConfirmationPresented = true
    }

    private func delete(_ machine: SavedMachine) {
        AppLog.ui.info("Deleting saved machine from card menu; id=\(machine.id.uuidString, privacy: .public) name=\(machine.displayName, privacy: .public)")
        pendingDeletionMachine = nil
        isDeleteConfirmationPresented = false

        if editingMachine?.id == machine.id {
            editingMachine = nil
        }

        if pendingConnectionMachine?.id == machine.id {
            pendingConnectionMachine = nil
            pendingConnectionPassword = ""
        }

        machineReachabilityStatuses[machine.id] = nil
        machineReachabilityEndpoints[machine.id] = nil
        store.delete(machine)
    }

    private func refreshMachines() {
        Task {
            await refreshMachineList(reason: "toolbar", marksMachinesChecking: false)
        }
    }

    private func openSettings() {
        isSettingsPresented = true
    }

    private func dismissSettings() {
        isSettingsPresented = false
    }

    private func refreshNearbyMacs() {
        Task {
            await refreshMachineList(reason: "nearby", marksMachinesChecking: false)
        }
    }

    private func queueConnectionAfterEditor(machine: SavedMachine, password: String) {
        AppLog.ui.info("Queued connection after editor dismiss for \(machine.host, privacy: .public):\(machine.port, privacy: .public)")
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

    private func handleIntentRequest(_ request: AppIntentRequest) {
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
            Task {
                await refreshMachineList(reason: "appIntentReloadMachines", marksMachinesChecking: false)
            }
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
        store.recordConnection(to: machine)
        session.connect(host: machine.host,
                        port: machine.port,
                        username: machine.username,
                        password: password)

        isSessionPresented = true
    }

    // MARK: - Reachability

    private func reachabilityStatus(for machine: SavedMachine) -> MachineReachabilityStatus {
        machineReachabilityStatuses[machine.id] ?? .checking
    }

    @MainActor
    private func monitorSavedMachineReachability() async {
        AppLog.reachability.info("Starting saved machine reachability monitor")
        pruneSavedMachineReachabilityState()

        while !Task.isCancelled {
            AppLog.reachability.debug("Saved machine reachability monitor tick")
            await refreshSavedMachineReachability()

            guard !Task.isCancelled else { break }

            try? await Task.sleep(for: reachabilityRefreshInterval)
        }

        AppLog.reachability.info("Saved machine reachability monitor stopped")
    }

    @MainActor
    private func refreshSavedMachineReachability() async {
        await refreshSavedMachineReachability(showChecking: false)
    }

    @MainActor
    private func refreshSavedMachineReachability(showChecking: Bool) async {
        let machines = store.machines

        guard !machines.isEmpty else {
            AppLog.reachability.info("Skipping saved machine reachability refresh because there are no saved machines")
            machineReachabilityStatuses.removeAll()
            machineReachabilityEndpoints.removeAll()
            return
        }

        let previousGeneration = reachabilityProbeGeneration
        AppLog.reachability.info("Starting saved machine reachability refresh; count=\(machines.count, privacy: .public) showChecking=\(showChecking, privacy: .public) previousGeneration=\(previousGeneration, privacy: .public)")
        prepareReachabilityState(for: machines)

        if showChecking {
            AppLog.reachability.debug("Marking saved machines as checking before probe refresh")
            machines.forEach { machineReachabilityStatuses[$0.id] = .checking }
        }

        reachabilityProbeGeneration += 1
        let generation = reachabilityProbeGeneration
        let startedAt = ContinuousClock.now

        await withTaskGroup(of: (UUID, String, MachineReachabilityStatus).self) { group in
            for machine in machines {
                let id = machine.id
                let host = machine.host.trimmingCharacters(in: .whitespacesAndNewlines)
                let port = machine.port
                let endpointKey = reachabilityEndpointKey(host: host, port: port)

                AppLog.reachability.debug("Queueing saved machine reachability probe; generation=\(generation, privacy: .public) id=\(id.uuidString, privacy: .public) name=\(machine.displayName, privacy: .public) endpoint=\(endpointKey, privacy: .public)")
                group.addTask {
                    await MainActor.run {
                        AppLog.reachability.debug("Launching saved machine reachability probe; generation=\(generation, privacy: .public) id=\(id.uuidString, privacy: .public) endpoint=\(endpointKey, privacy: .public)")
                    }
                    let status = await MachineReachabilityProber.status(host: host, port: port)
                    return (id, endpointKey, status)
                }
            }

            for await (id, endpointKey, status) in group {
                guard reachabilityProbeGeneration == generation else {
                    AppLog.reachability.info("Discarding saved machine reachability generation because a newer refresh started; generation=\(generation, privacy: .public) currentGeneration=\(reachabilityProbeGeneration, privacy: .public)")
                    group.cancelAll()
                    return
                }

                if Task.isCancelled {
                    AppLog.reachability.info("Saved machine reachability refresh task is cancelled, applying completed result anyway; generation=\(generation, privacy: .public) id=\(id.uuidString, privacy: .public) endpoint=\(endpointKey, privacy: .public)")
                }

                guard machineReachabilityEndpoints[id] == endpointKey else {
                    let currentEndpoint = machineReachabilityEndpoints[id] ?? "missing"
                    AppLog.reachability.info("Skipping stale saved machine reachability result; generation=\(generation, privacy: .public) id=\(id.uuidString, privacy: .public) resultEndpoint=\(endpointKey, privacy: .public) currentEndpoint=\(currentEndpoint, privacy: .public) status=\(status.title, privacy: .public)")
                    continue
                }

                machineReachabilityStatuses[id] = status
                AppLog.reachability.info("Saved machine reachability result applied; generation=\(generation, privacy: .public) id=\(id.uuidString, privacy: .public) endpoint=\(endpointKey, privacy: .public) status=\(status.title, privacy: .public)")
            }
        }

        let elapsed = String(describing: startedAt.duration(to: .now))
        AppLog.reachability.info("Finished saved machine reachability refresh; generation=\(generation, privacy: .public) elapsed=\(elapsed, privacy: .public) taskCancelled=\(Task.isCancelled, privacy: .public)")
    }

    @MainActor
    private func refreshMachineList(reason: String, marksMachinesChecking: Bool) async {
        AppLog.ui.info("Refreshing machine list; reason=\(reason, privacy: .public) marksMachinesChecking=\(marksMachinesChecking, privacy: .public)")
        store.reload()
        restartNearbyMacDiscovery()
        await refreshSavedMachineReachability(showChecking: marksMachinesChecking)
    }

    @MainActor
    private func refreshForNetworkPathChange(_ snapshot: NetworkPathSnapshot) async {
        AppLog.ui.info("Network path changed; \(snapshot.logDescription, privacy: .public)")
        store.reload()
        restartNearbyMacDiscovery()

        switch snapshot.status {
        case .satisfied:
            await refreshSavedMachineReachability(showChecking: true)
        case .requiresConnection, .unsatisfied:
            setSavedMachineReachabilityStatuses(.unreachable)
        }
    }

    private func prepareReachabilityState(for machines: [SavedMachine]) {
        let activeIDs = Set(machines.map(\.id))
        let previousStatusCount = machineReachabilityStatuses.count
        let previousEndpointCount = machineReachabilityEndpoints.count

        machineReachabilityStatuses = machineReachabilityStatuses.filter { activeIDs.contains($0.key) }
        machineReachabilityEndpoints = machineReachabilityEndpoints.filter { activeIDs.contains($0.key) }

        let prunedStatusCount = previousStatusCount - machineReachabilityStatuses.count
        let prunedEndpointCount = previousEndpointCount - machineReachabilityEndpoints.count
        if prunedStatusCount > 0 || prunedEndpointCount > 0 {
            AppLog.reachability.debug("Pruned saved machine reachability state; statusCount=\(prunedStatusCount, privacy: .public) endpointCount=\(prunedEndpointCount, privacy: .public)")
        }

        for machine in machines {
            let endpointKey = reachabilityEndpointKey(for: machine)

            if machineReachabilityEndpoints[machine.id] != endpointKey {
                let previousEndpoint = machineReachabilityEndpoints[machine.id] ?? "missing"
                AppLog.reachability.debug("Saved machine reachability endpoint changed; id=\(machine.id.uuidString, privacy: .public) name=\(machine.displayName, privacy: .public) previous=\(previousEndpoint, privacy: .public) current=\(endpointKey, privacy: .public)")
                machineReachabilityEndpoints[machine.id] = endpointKey
                machineReachabilityStatuses[machine.id] = .checking
            } else if machineReachabilityStatuses[machine.id] == nil {
                AppLog.reachability.debug("Saved machine reachability status missing; id=\(machine.id.uuidString, privacy: .public) name=\(machine.displayName, privacy: .public) endpoint=\(endpointKey, privacy: .public)")
                machineReachabilityStatuses[machine.id] = .checking
            }
        }
    }

    private func pruneSavedMachineReachabilityState() {
        let activeIDs = Set(store.machines.map(\.id))

        machineReachabilityStatuses = machineReachabilityStatuses.filter { activeIDs.contains($0.key) }
        machineReachabilityEndpoints = machineReachabilityEndpoints.filter { activeIDs.contains($0.key) }
    }

    private func restartNearbyMacDiscovery() {
        browser.stop()
        browser.start()
    }

    private func setSavedMachineReachabilityStatuses(_ status: MachineReachabilityStatus) {
        reachabilityProbeGeneration += 1
        AppLog.reachability.info("Setting all saved machine reachability statuses; status=\(status.title, privacy: .public) generation=\(reachabilityProbeGeneration, privacy: .public) count=\(store.machines.count, privacy: .public)")
        prepareReachabilityState(for: store.machines)

        for machine in store.machines {
            machineReachabilityStatuses[machine.id] = status
        }
    }

    private func reachabilityEndpointKey(for machine: SavedMachine) -> String {
        reachabilityEndpointKey(host: machine.host, port: machine.port)
    }

    private func reachabilityEndpointKey(host: String, port: UInt16) -> String {
        "\(host.trimmingCharacters(in: .whitespacesAndNewlines)):\(port)"
    }
}

extension ContentView where Session == VNCSession,
                            Browser == BonjourBrowser,
                            Store == MachineStore,
                            Router == AppIntentRouter {
    @MainActor
    init() {
        self.init(dependencies: .live)
    }
}

#Preview {
    ContentView()
        .environment(SubscriptionStore())
}
