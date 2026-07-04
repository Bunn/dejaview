import SwiftUI

struct DiscoveredServiceTile: View {
    let service: DiscoveredService
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            HStack(spacing: 14) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.green)
                    .frame(width: 44, height: 44)
                    .background(.green.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(service.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(service.isResolved ? .subheadline.monospaced() : .subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: service.isResolved ? "arrow.down.left.circle.fill" : "clock")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(service.isResolved ? Color.accentColor : Color.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!service.isResolved)
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        .glassPanel(cornerRadius: 24, isInteractive: service.isResolved)
        .accessibilityHint(service.isResolved ? "Fills the manual connection fields." : "Address is still resolving.")
    }

    private var subtitle: String {
        guard let host = service.host, let port = service.port else {
            return "Resolving address..."
        }

        return "\(host):\(String(port))"
    }
}
