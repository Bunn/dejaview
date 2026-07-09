import SwiftUI

struct RecentConnectionTile: View {
    let entry: ConnectionHistoryEntry
    let canReconnectDirectly: Bool
    let connect: () -> Void
    let delete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: connect) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: entry.outcome.systemImage)
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(outcomeColor)
                            .frame(width: 44, height: 44)
                            .background(outcomeColor.opacity(0.14), in: Circle())
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 5) {
                            Text(entry.displayName)
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .lineLimit(2)

                            Text(entry.subtitle)
                                .font(.subheadline.monospaced())
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Image(systemName: canReconnectDirectly ? "play.circle.fill" : "person.badge.key")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.tint)
                            .frame(width: 44, height: 44)
                            .accessibilityHidden(true)
                    }

                    RecentConnectionSessionDetails(entry: entry)
                        .padding(.leading, 58)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(canReconnectDirectly
                               ? "Reconnects to this machine."
                               : "Opens connection details to enter credentials.")

            Menu("Recent Session Options", systemImage: "ellipsis.circle") {
                Button("Remove from Recents", systemImage: "trash", role: .destructive, action: delete)
            }
            .labelStyle(.iconOnly)
            .font(.title3)
            .frame(width: 44, height: 44)
            .contentShape(Circle())
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .leading)
        .glassPanel(cornerRadius: 24, isInteractive: true)
        .contextMenu {
            Button("Remove from Recents", systemImage: "trash", role: .destructive, action: delete)
        }
    }

    private var outcomeColor: Color {
        switch entry.outcome {
        case .completed:
            .green
        case .interrupted:
            .orange
        }
    }

}
