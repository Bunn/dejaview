import SwiftUI

struct SavedMachineTile: View {
    let machine: SavedMachine
    let reachabilityStatus: MachineReachabilityStatus
    let isWaking: Bool
    let connect: () -> Void
    let wakeAndConnect: (() -> Void)?
    let cancelWake: () -> Void
    let edit: () -> Void
    let delete: () -> Void

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

                    if isWaking {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 24, height: 24)
                    } else {
                        Image(systemName: "play.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.tint)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isWaking)
            .accessibilityHint(primaryActionAccessibilityHint)

            Menu {
                machineActions
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Machine Options")
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        .glassPanel(cornerRadius: 24, isInteractive: true)
        .contextMenu {
            machineActions
        }
    }

    @ViewBuilder
    private var machineActions: some View {
        if isWaking {
            Button("Cancel Wake Attempt", systemImage: "xmark.circle", action: cancelWake)
        } else if let wakeAndConnect {
            Button("Wake and Connect", systemImage: "power", action: wakeAndConnect)
        }

        Button("Edit", systemImage: "slider.horizontal.3", action: edit)

        Button("Delete", systemImage: "trash", role: .destructive, action: delete)
    }

    private var primaryActionAccessibilityHint: String {
        if isWaking {
            "Waiting for this Mac to wake."
        } else if wakeAndConnect != nil && reachabilityStatus != .reachable {
            "Wakes this Mac if needed, then connects."
        } else {
            "Connects to this saved machine."
        }
    }
}
