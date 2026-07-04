import SwiftUI

/// Sheet for creating or editing a saved machine.
struct EditMachineView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: MachineStore
    let connectWithoutSaving: ((SavedMachine, String) -> Void)?

    @State private var machine: SavedMachine
    @State private var password: String
    @State private var portText: String

    init(store: MachineStore,
         machine: SavedMachine,
         password: String,
         connectWithoutSaving: ((SavedMachine, String) -> Void)? = nil) {
        self.store = store
        self.connectWithoutSaving = connectWithoutSaving
        _machine = State(initialValue: machine)
        _password = State(initialValue: password)
        _portText = State(initialValue: String(machine.port))
    }

    private var isNew: Bool {
        !store.contains(machine)
    }

    private var canSubmit: Bool {
        !machine.host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Machine") {
                    TextField("Name (optional)", text: $machine.name)

                    TextField("Host or IP address", text: $machine.host)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)

                    TextField("Port", text: $portText)
                        .keyboardType(.numberPad)
                }

                Section("Login") {
                    TextField("Username (macOS login)", text: $machine.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    SecureField("Password", text: $password)
                }

                if isNew, connectWithoutSaving != nil {
                    Section {
                        Button("Connect Without Saving", systemImage: "display") {
                            connectNow()
                        }
                        .disabled(!canSubmit)
                    }
                }

                if !isNew {
                    Section {
                        Button("Delete Machine", role: .destructive) {
                            store.delete(machine)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "New Machine" : "Edit Machine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(!canSubmit)
                }
            }
        }
    }

    private func save() {
        machine = preparedMachine()

        if isNew {
            store.add(machine, password: password)
        } else {
            store.update(machine, password: password)
        }

        dismiss()
    }

    private func connectNow() {
        connectWithoutSaving?(preparedMachine(), password)
        dismiss()
    }

    private func preparedMachine() -> SavedMachine {
        var prepared = machine
        prepared.host = prepared.host.trimmingCharacters(in: .whitespacesAndNewlines)
        prepared.port = UInt16(portText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 5900

        if prepared.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            prepared.name = prepared.host
        }

        return prepared
    }
}
