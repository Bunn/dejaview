import SwiftUI

/// Sheet for creating or editing a saved machine.
struct EditMachineView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: MachineStore

    @State private var machine: SavedMachine
    @State private var password: String
    @State private var portText: String

    init(store: MachineStore, machine: SavedMachine, password: String) {
        self.store = store
        _machine = State(initialValue: machine)
        _password = State(initialValue: password)
        _portText = State(initialValue: String(machine.port))
    }

    private var isNew: Bool {
        !store.contains(machine)
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
                    .disabled(machine.host.isEmpty)
                }
            }
        }
    }

    private func save() {
        machine.port = UInt16(portText) ?? 5900

        if machine.name.trimmingCharacters(in: .whitespaces).isEmpty {
            machine.name = machine.host
        }

        if isNew {
            store.add(machine, password: password)
        } else {
            store.update(machine, password: password)
        }

        dismiss()
    }
}
