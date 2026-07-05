import SwiftUI

struct ReachabilityStatusBadge: View {
    let status: MachineReachabilityStatus

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(status.color)
                .frame(width: 8, height: 8)

            Text(status.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(status.color)
                .lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Reachability")
        .accessibilityValue(status.title)
    }
}

private extension MachineReachabilityStatus {
    var color: Color {
        switch self {
        case .checking:
            .orange
        case .reachable:
            .green
        case .unreachable:
            .red
        }
    }
}
