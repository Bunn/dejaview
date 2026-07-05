import SwiftUI

struct SavedMachineTile: View {
    let machine: SavedMachine
    let reachabilityStatus: MachineReachabilityStatus
    let connect: () -> Void
    let edit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: connect) {
                HStack(spacing: 14) {
                    Image(systemName: "desktopcomputer")
                        .font(.title3)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.tint)
                        .frame(width: 44, height: 44)
                        .background(.tint.opacity(0.14), in: Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text(machine.displayName)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Text(machine.subtitle)
                            .font(.subheadline.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        ReachabilityStatusBadge(status: reachabilityStatus)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "play.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.tint)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Connects to this saved machine.")

            Menu("Machine Options", systemImage: "ellipsis.circle") {
                Button("Edit", systemImage: "slider.horizontal.3", action: edit)
            }
            .labelStyle(.iconOnly)
            .frame(width: 44, height: 44)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        .glassPanel(cornerRadius: 24, isInteractive: true)
    }
}
