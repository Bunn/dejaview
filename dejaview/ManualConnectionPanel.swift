import SwiftUI

struct ManualConnectionPanel: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @FocusState private var focusedField: ManualConnectionField?

    @Binding var host: String
    @Binding var port: String
    @Binding var username: String
    @Binding var password: String

    let save: () -> Void
    let connect: () -> Void
    let clear: () -> Void

    private var canConnect: Bool {
        !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasInput: Bool {
        port.trimmingCharacters(in: .whitespacesAndNewlines) != "5900" ||
        [host, username, password].contains {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private var usesCompactLayout: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Label("Manual Connection", systemImage: "keyboard")
                    .font(.headline)

                Spacer()

                if hasInput {
                    Button("Clear", systemImage: "xmark.circle", action: clear)
                        .buttonStyle(.borderless)
                }
            }

            VStack(spacing: 12) {
                TextField("Host or IP address", text: $host)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .host)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .port
                    }

                if usesCompactLayout {
                    VStack(spacing: 12) {
                        portField
                        usernameField
                    }
                } else {
                    HStack(spacing: 12) {
                        portField
                        usernameField
                    }
                }

                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .password)
                    .submitLabel(.go)
                    .onSubmit {
                        if canConnect {
                            connect()
                        }
                    }
            }

            if usesCompactLayout {
                VStack(spacing: 12) {
                    saveButton
                    connectButton
                }
            } else {
                HStack(spacing: 12) {
                    saveButton
                    connectButton
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(cornerRadius: 28)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()

                Button("Done") {
                    focusedField = nil
                }
            }
        }
    }

    private var portField: some View {
        TextField("Port", text: $port)
            .keyboardType(.numberPad)
            .textFieldStyle(.roundedBorder)
            .frame(minWidth: 110)
            .focused($focusedField, equals: .port)
            .submitLabel(.next)
            .onSubmit {
                focusedField = .username
            }
    }

    private var usernameField: some View {
        TextField("Username", text: $username)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .textContentType(.username)
            .textFieldStyle(.roundedBorder)
            .focused($focusedField, equals: .username)
            .submitLabel(.next)
            .onSubmit {
                focusedField = .password
            }
    }

    private var saveButton: some View {
        Button("Save", systemImage: "bookmark", action: save)
            .font(.headline)
            .frame(minHeight: 44)
            .glassButtonStyle()
            .disabled(!canConnect)
    }

    private var connectButton: some View {
        Button("Connect", systemImage: "display", action: connect)
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 44)
            .prominentGlassButtonStyle()
            .disabled(!canConnect)
    }
}
