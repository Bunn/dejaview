import SwiftUI
import OSLog

/// Full-screen remote session with floating Liquid Glass controls.
struct SessionView<Session: RemoteSessionControlling>: View {
    @ObservedObject var session: Session
    @Environment(SubscriptionStore.self) private var subscriptionStore
    @Environment(\.dismiss) private var dismiss

    @State private var isSessionPaywallPresented = false
    @State private var isFreeSessionTimerInfoPresented = false
    @State private var freeSessionEndDate: Date?
    @State private var shouldEndSessionOnPaywallDismiss = false
    @State private var opensPaywallAfterFreeSessionInfoDismissal = false
    @State private var pendingPaywallEndsSessionOnDismiss = false
    @State private var showsInputBar = false
    @State private var textToSend = ""
    @State private var streamZoomScale: CGFloat = 1
    @State private var followsCursorWhenZoomed = true
    @FocusState private var inputFocused: Bool

    private let freeSessionDuration: Duration = .seconds(120)
    private let freeSessionDurationInterval: TimeInterval = 120

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
        .overlay(alignment: .topLeading) {
            if isConnectedFreeSession, let freeSessionEndDate {
                FreeSessionTimerPill(endDate: freeSessionEndDate,
                                     action: presentFreeSessionTimerInfo)
                    .padding(.top, 20)
                    .padding(.leading, 20)
            }
        }
        .overlay(alignment: .bottom) {
            if showsInputBar && session.status == .connected {
                inputBar
            }
        }
        .overlay(alignment: .bottomLeading) {
            if session.status == .connected && !showsInputBar {
                SessionZoomControls(zoomScale: $streamZoomScale,
                                    followsCursor: $followsCursorWhenZoomed)
                    .padding(.bottom, 28)
                    .padding(.leading, 20)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if session.status == .connected && !showsInputBar {
                HStack(spacing: 10) {
                    if session.displayOptions.count > 1 {
                        SessionDisplayMenu(session: session)
                    }

                    SessionOptionsMenu(session: session)
                }
                .padding(.bottom, 28)
                .padding(.trailing, 20)
            }
        }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $isSessionPaywallPresented,
               onDismiss: handleSessionPaywallDismissed) {
            RevenueCatPaywallSheet(onProAccessGranted: handleSessionProAccessGranted)
        }
        .sheet(isPresented: $isFreeSessionTimerInfoPresented,
               onDismiss: handleFreeSessionTimerInfoDismissed) {
            FreeSessionTimerSheet(endDate: freeSessionEndDate,
                                  purchase: purchaseFromFreeSessionTimerInfo)
        }
        .onAppear {
            logDisplayControlState(reason: "sessionViewAppeared")
        }
        .onChange(of: session.status) { _, _ in
            logDisplayControlState(reason: "statusChanged")
        }
        .onChange(of: session.displays) { _, _ in
            logDisplayControlState(reason: "displayLayoutChanged")
        }
        .onChange(of: session.displaySelection) { _, _ in
            logDisplayControlState(reason: "displaySelectionChanged")
        }
        .onChange(of: showsInputBar) { _, _ in
            logDisplayControlState(reason: "inputBarVisibilityChanged")
        }
        .onChange(of: subscriptionStore.hasProAccess) { _, hasProAccess in
            if hasProAccess {
                handleSessionProAccessGranted()
                freeSessionEndDate = nil
            }
        }
        .task(id: isConnectedFreeSession) {
            await enforceFreeSessionLimitIfNeeded()
        }
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
                    AppLog.ui.info("Connection cancel button tapped")
                    session.disconnect()
                    dismiss()
                }
                .buttonStyle(.glass)
            }

        case .connected:
            RemoteDesktopView(session: session,
                              selectedFramebufferFrame: session.selectedDisplayFrame,
                              zoomScale: $streamZoomScale,
                              followsCursor: followsCursorWhenZoomed)
                .id(session.displaySelection.id)
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
                        AppLog.ui.info("Disconnected session close button tapped")
                        dismiss()
                    }
                    .buttonStyle(.glass)

                    Button("Reconnect") {
                        AppLog.ui.info("Reconnect button tapped")
                        session.retryConnect()
                    }
                    .buttonStyle(.glassProminent)
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
                AppLog.ui.info("Software input bar visibility changed; visible=\(self.showsInputBar, privacy: .public)")
                inputFocused = showsInputBar
            } label: {
                Image(systemName: "keyboard")
                    .padding(12)
                    .contentShape(Rectangle())
            }

            Button {
                AppLog.ui.info("Session close button tapped")
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

    private var isConnectedFreeSession: Bool {
        session.status == .connected && !subscriptionStore.hasProAccess
    }

    private var freeSessionHasExpired: Bool {
        guard let freeSessionEndDate else { return false }
        return freeSessionEndDate <= Date.now
    }

    private func logDisplayControlState(reason: String) {
        let displayCount = session.displays.count
        let bottomControlsVisible = session.status == .connected && !showsInputBar
        let displayOptionCount = session.displayOptions.count
        let displayControlVisible = bottomControlsVisible && displayOptionCount > 1
        let optionDescription = session.displayOptions.map(\.logDescription).joined(separator: "; ")
        let layoutDescription = session.displays.isEmpty
            ? "none"
            : session.displays.map(\.logDescription).joined(separator: "; ")

        AppLog.ui.info("Session display controls state; reason=\(reason, privacy: .public) status=\(self.session.status.logDescription, privacy: .public) displayCount=\(displayCount, privacy: .public) selection=\(self.session.displaySelection.logDescription, privacy: .public) bottomControlsVisible=\(bottomControlsVisible, privacy: .public) displayControlVisible=\(displayControlVisible, privacy: .public) displayOptionCount=\(displayOptionCount, privacy: .public) displayOptions=\(optionDescription, privacy: .public) inputBarVisible=\(self.showsInputBar, privacy: .public) layout=\(layoutDescription, privacy: .public)")
    }

    private func enforceFreeSessionLimitIfNeeded() async {
        guard isConnectedFreeSession else {
            freeSessionEndDate = nil
            return
        }

        freeSessionEndDate = Date.now.addingTimeInterval(freeSessionDurationInterval)

        try? await Task.sleep(for: freeSessionDuration)

        guard !Task.isCancelled else { return }
        guard session.status == .connected else { return }
        guard !subscriptionStore.hasProAccess else { return }

        AppLog.subscriptions.info("Free session limit reached; presenting paywall")
        presentSessionPaywall(endsSessionOnDismiss: true)
    }

    private func handleSessionProAccessGranted() {
        guard isSessionPaywallPresented else { return }

        AppLog.subscriptions.info("Pro access granted from session paywall; keeping remote session active")
        shouldEndSessionOnPaywallDismiss = false
        isSessionPaywallPresented = false
        freeSessionEndDate = nil
    }

    private func handleSessionPaywallDismissed() {
        let shouldEndSession = shouldEndSessionOnPaywallDismiss
        shouldEndSessionOnPaywallDismiss = false

        Task {
            await subscriptionStore.refresh()

            guard shouldEndSession else { return }
            guard session.status == .connected else { return }
            guard !subscriptionStore.hasProAccess else { return }

            AppLog.subscriptions.info("Session paywall dismissed without Pro access; ending remote session")
            session.disconnect()
            dismiss()
        }
    }

    private func presentFreeSessionTimerInfo() {
        guard isConnectedFreeSession else { return }

        AppLog.subscriptions.info("Free session timer tapped")
        isFreeSessionTimerInfoPresented = true
    }

    private func purchaseFromFreeSessionTimerInfo() {
        AppLog.subscriptions.info("Free session timer purchase button tapped")
        presentSessionPaywall(endsSessionOnDismiss: freeSessionHasExpired)
    }

    private func handleFreeSessionTimerInfoDismissed() {
        guard opensPaywallAfterFreeSessionInfoDismissal else { return }

        opensPaywallAfterFreeSessionInfoDismissal = false
        let endsSessionOnDismiss = pendingPaywallEndsSessionOnDismiss
        pendingPaywallEndsSessionOnDismiss = false
        presentSessionPaywall(endsSessionOnDismiss: endsSessionOnDismiss)
    }

    private func presentSessionPaywall(endsSessionOnDismiss: Bool) {
        if isSessionPaywallPresented {
            shouldEndSessionOnPaywallDismiss = shouldEndSessionOnPaywallDismiss || endsSessionOnDismiss
            return
        }

        if isFreeSessionTimerInfoPresented {
            pendingPaywallEndsSessionOnDismiss = endsSessionOnDismiss
            opensPaywallAfterFreeSessionInfoDismissal = true
            isFreeSessionTimerInfoPresented = false
            return
        }

        shouldEndSessionOnPaywallDismiss = endsSessionOnDismiss
        isSessionPaywallPresented = true
    }

    private var inputBar: some View {
        VStack(spacing: 8) {
            SessionShortcutStrip(session: session) {
                inputFocused = true
            }

            HStack(spacing: 10) {
                TextField("Type to send to the Mac…", text: $textToSend)
                    .textFieldStyle(.plain)
                    .focused($inputFocused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit {
                        AppLog.ui.debug("Software input submitted; characterCount=\(self.textToSend.count, privacy: .public)")
                        session.sendText(textToSend)
                        textToSend = ""
                        inputFocused = true
                    }

                Button {
                    AppLog.ui.debug("Software return key tapped")
                    session.sendReturn()
                    inputFocused = true
                } label: {
                    Image(systemName: "return")
                        .fontWeight(.medium)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .liquidGlass(in: Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
}
