import SwiftUI

struct RecentConnectionSessionDetails: View {
    let entry: ConnectionHistoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(entry.outcome.title, systemImage: entry.outcome.systemImage)
                .foregroundStyle(outcomeColor)

            Label("Connected \(connectedDescription)", systemImage: "clock")

            if let duration = entry.duration {
                Label("Duration \(durationDescription(duration))", systemImage: "timer")
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var outcomeColor: Color {
        switch entry.outcome {
        case .completed:
            .green
        case .interrupted:
            .orange
        }
    }

    private var connectedDescription: String {
        entry.connectedAt.formatted(.relative(presentation: .named,
                                              unitsStyle: .abbreviated))
    }

    private func durationDescription(_ duration: TimeInterval) -> String {
        Duration.seconds(duration)
            .formatted(.units(allowed: [.hours, .minutes, .seconds], width: .abbreviated))
    }
}
