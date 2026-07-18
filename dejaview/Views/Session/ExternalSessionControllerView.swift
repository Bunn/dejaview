import SwiftUI

struct ExternalSessionControllerView<Session: RemoteSessionControlling>: View {
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    let session: Session
    let sessionTitle: String
    @Binding var heldModifierKeys: Set<RemoteModifierKey>
    let stopControllerMode: () -> Void

    @State private var textToSend = ""
    @State private var trackpadZoomScale: CGFloat = 1
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 14) {
            if verticalSizeClass == .compact {
                compactHeader
            } else {
                header
            }

            trackpad

            if verticalSizeClass != .compact {
                SessionShortcutStrip(session: session,
                                     heldModifierKeys: $heldModifierKeys,
                                     onSend: focusInput)
            }

            inputBar
        }
        .padding(.horizontal, 16)
        .padding(.top, verticalSizeClass == .compact ? 56 : 74)
        .padding(.bottom, verticalSizeClass == .compact ? 56 : 76)
        .background {
            LinearGradient(colors: [.black, Color(uiColor: .secondarySystemBackground)],
                           startPoint: .top,
                           endPoint: .bottom)
                .ignoresSafeArea()
        }
        .task {
            await Task.yield()
            inputFocused = true
        }
    }

    private var compactHeader: some View {
        HStack {
            Label(sessionTitle, systemImage: "rectangle.connected.to.line.below")
                .font(.headline)
                .lineLimit(1)

            Spacer(minLength: 12)

            Button("Show Here", systemImage: "rectangle.on.rectangle", action: stopControllerMode)
                .buttonStyle(.glass)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "rectangle.connected.to.line.below")
                .font(.title2)
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(sessionTitle)
                    .font(.headline)
                    .lineLimit(1)

                Text("Remote desktop is on the external display")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            Button("Show Here", systemImage: "rectangle.on.rectangle", action: stopControllerMode)
                .buttonStyle(.glass)
        }
    }

    private var trackpad: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28)
                .fill(.white.opacity(0.08))
                .stroke(.white.opacity(0.18), lineWidth: 1)

            RemoteDesktopView(session: session,
                              selectedFramebufferFrame: session.selectedDisplayFrame,
                              zoomScale: $trackpadZoomScale,
                              followsCursor: false,
                              acceptsHardwareKeyboardInput: false,
                              showsFramebuffer: false,
                              touchModeOverride: .trackpad)
                .clipShape(.rect(cornerRadius: 28))

            VStack(spacing: 8) {
                Image(systemName: "hand.draw")
                    .font(.largeTitle)

                Text("Trackpad")
                    .font(.headline)

                Text("Move with one finger • Scroll with two • Two-finger tap to right-click")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minHeight: verticalSizeClass == .compact ? 96 : 180)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Remote trackpad")
        .accessibilityHint("Move with one finger, scroll with two fingers, or tap with two fingers to right-click.")
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Type to send to the Mac…", text: $textToSend)
                .textFieldStyle(.plain)
                .focused($inputFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onSubmit(sendText)

            Button("Send Return", systemImage: "return", action: sendReturn)
                .labelStyle(.iconOnly)
                .font(.body.weight(.medium))
                .frame(minWidth: 44, minHeight: 44)
        }
        .padding(.leading, 18)
        .padding(.trailing, 8)
        .padding(.vertical, 6)
        .liquidGlass(in: Capsule())
    }

    private func sendText() {
        guard !textToSend.isEmpty else { return }

        session.sendText(textToSend)
        textToSend = ""
        focusInput()
    }

    private func sendReturn() {
        session.sendReturn()
        focusInput()
    }

    private func focusInput() {
        inputFocused = true
    }
}
