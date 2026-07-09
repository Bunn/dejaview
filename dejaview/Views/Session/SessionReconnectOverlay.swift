import SwiftUI

struct SessionReconnectOverlay: View {
    let state: RemoteReconnectState
    let retryNow: () -> Void
    let cancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)

            VStack(spacing: 6) {
                Text("Reconnecting…")
                    .font(.title3)
                    .bold()

                SessionReconnectPhaseDescription(phase: state.phase)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Text("Attempt \(state.attempt) of \(state.maximumAttempts)")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 12) {
                Button("Cancel", action: cancel)
                    .buttonStyle(.glass)

                Button("Retry Now", systemImage: "arrow.clockwise", action: retryNow)
                    .buttonStyle(.glassProminent)
                    .disabled(!state.canRetryImmediately)
            }
            .controlSize(.large)
        }
        .padding(24)
        .frame(maxWidth: 360)
        .glassPanel(cornerRadius: 28)
        .padding(24)
        .accessibilityElement(children: .contain)
    }
}
