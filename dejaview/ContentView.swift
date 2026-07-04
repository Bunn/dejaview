import SwiftUI

struct ContentView: View {
    @StateObject private var session = VNCSession()
    @StateObject private var browser = BonjourBrowser()
    @StateObject private var store = MachineStore()

    @State private var host = ""
    @State private var port = "5900"
    @State private var username = ""
    @State private var password = ""
    @State private var isSessionPresented = false

    @State private var editingMachine: SavedMachine?
    @State private var editingPassword = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    savedMachinesCard
                    discoveredCard
                    connectionCard
                    footerHint
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Deja View")
        }
        .fullScreenCover(isPresented: $isSessionPresented, onDismiss: session.reset) {
            SessionView(session: session)
        }
        .sheet(item: $editingMachine) { machine in
            EditMachineView(store: store, machine: machine, password: editingPassword)
        }
        .onAppear { browser.start() }
    }

    // MARK: - Saved machines

    private var savedMachinesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Saved Machines")
                    .font(.headline)

                Spacer()

                Button {
                    editingPassword = ""
                    editingMachine = SavedMachine(name: "", host: "", username: "")
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
            }

            if store.machines.isEmpty {
                Text("Save a machine to connect with one tap.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            }

            ForEach(store.machines) { machine in
                savedMachineRow(machine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func savedMachineRow(_ machine: SavedMachine) -> some View {
        HStack(spacing: 6) {
            Button {
                connect(to: machine)
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "desktopcomputer")
                        .font(.title3)
                        .foregroundStyle(.tint)
                        .frame(width: 40, height: 40)
                        .background(.tint.opacity(0.12), in: Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(machine.displayName)
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)

                        Text(machine.subtitle)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "play.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.tint)
                }
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                editingPassword = store.password(for: machine)
                editingMachine = machine
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Manual connection

    private var connectionCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Manual Connection")
                    .font(.headline)

                Spacer()
            }

            VStack(spacing: 0) {
                field(icon: "desktopcomputer") {
                    TextField("Host or IP address", text: $host)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                }

                Divider().padding(.leading, 40)

                field(icon: "number") {
                    TextField("Port", text: $port)
                        .keyboardType(.numberPad)
                }

                Divider().padding(.leading, 40)

                field(icon: "person") {
                    TextField("Username (macOS login)", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Divider().padding(.leading, 40)

                field(icon: "key") {
                    SecureField("Password", text: $password)
                }
            }

            HStack(spacing: 12) {
                Button {
                    editingPassword = password
                    editingMachine = SavedMachine(name: "",
                                                  host: host,
                                                  port: UInt16(port) ?? 5900,
                                                  username: username)
                } label: {
                    Label("Save", systemImage: "bookmark")
                        .font(.headline)
                        .padding(.vertical, 6)
                }
                .glassButtonStyle()
                .disabled(host.isEmpty)

                Button {
                    connect()
                } label: {
                    Label("Connect", systemImage: "display")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .prominentGlassButtonStyle()
                .disabled(host.isEmpty)
            }
        }
        .cardStyle()
    }

    private func field(icon: String, @ViewBuilder content: () -> some View) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 28)

            content()
        }
        .padding(.vertical, 12)
    }

    // MARK: - Discovered Macs

    private var discoveredCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("On Your Network")
                .font(.headline)

            if browser.services.isEmpty {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Looking for Macs with Screen Sharing on…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }

            ForEach(browser.services) { service in
                Button {
                    select(service)
                } label: {
                    serviceRow(service)
                }
                .buttonStyle(.plain)
                .disabled(!service.isResolved)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func serviceRow(_ service: DiscoveredService) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "wifi")
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 40, height: 40)
                .background(.tint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(service.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)

                if let serviceHost = service.host, let servicePort = service.port {
                    Text("\(serviceHost):\(String(servicePort))")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                } else {
                    Text("Resolving address…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private var footerHint: some View {
        Text("Tapping a discovered Mac fills in the manual connection form. To share a Mac's screen, enable Screen Sharing on it in System Settings → General → Sharing.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }

    // MARK: - Actions

    private func select(_ service: DiscoveredService) {
        guard let serviceHost = service.host, let servicePort = service.port else { return }

        host = serviceHost
        port = String(servicePort)
    }

    private func connect() {
        session.connect(host: host,
                        port: UInt16(port) ?? 5900,
                        username: username,
                        password: password)

        isSessionPresented = true
    }

    private func connect(to machine: SavedMachine) {
        session.connect(host: machine.host,
                        port: machine.port,
                        username: machine.username,
                        password: store.password(for: machine))

        isSessionPresented = true
    }
}

#Preview {
    ContentView()
}
