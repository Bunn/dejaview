import SwiftUI

/// Full-screen remote session with floating Liquid Glass controls.
struct SessionView: View {
    @ObservedObject var session: VNCSession
    @Environment(\.dismiss) private var dismiss

    @State private var showsInputBar = false
    @State private var textToSend = ""
    @FocusState private var inputFocused: Bool

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            content
        }
        .overlay(alignment: .topTrailing) {
            if session.status == .connected {
                controlPill
            }
        }
        .overlay(alignment: .bottom) {
            if showsInputBar && session.status == .connected {
                inputBar
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if session.status == .connected && !showsInputBar {
                SessionOptionsMenu(session: session)
                    .padding(.bottom, 28)
                    .padding(.trailing, 20)
            }
        }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .preferredColorScheme(.dark)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch session.status {
        case .idle, .connecting:
            VStack(spacing: 20) {
                ProgressView()
                    .controlSize(.large)

                Text("Connecting…")
                    .foregroundStyle(.secondary)

                Button("Cancel") {
                    session.disconnect()
                    dismiss()
                }
                .glassButtonStyle()
            }

        case .connected:
            RemoteDesktopView(session: session)
                .ignoresSafeArea()

        case .disconnected(let message):
            VStack(spacing: 14) {
                Image(systemName: "rectangle.on.rectangle.slash")
                    .font(.system(size: 44))
                    .foregroundStyle(.secondary)

                Text("Disconnected")
                    .font(.title3.weight(.semibold))

                if let message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                HStack(spacing: 12) {
                    Button("Close") {
                        dismiss()
                    }
                    .glassButtonStyle()

                    Button("Reconnect") {
                        session.retryConnect()
                    }
                    .prominentGlassButtonStyle()
                }
                .padding(.top, 8)
            }
        }
    }

    // MARK: - Floating controls

    private var controlPill: some View {
        HStack(spacing: 2) {
            Button {
                showsInputBar.toggle()
                inputFocused = showsInputBar
            } label: {
                Image(systemName: "keyboard")
                    .padding(12)
                    .contentShape(Rectangle())
            }

            Button {
                session.disconnect()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .padding(12)
                    .contentShape(Rectangle())
            }
        }
        .font(.body.weight(.medium))
        .foregroundStyle(.white)
        .liquidGlass(in: Capsule())
        .padding(.top, 20)
        .padding(.trailing, 20)
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Type to send to the Mac…", text: $textToSend)
                .textFieldStyle(.plain)
                .focused($inputFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onSubmit {
                    session.sendText(textToSend)
                    textToSend = ""
                    inputFocused = true
                }

            Button {
                session.sendReturn()
            } label: {
                Image(systemName: "return")
                    .fontWeight(.medium)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .liquidGlass(in: Capsule())
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
}
