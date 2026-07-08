import SwiftUI

struct FreeSessionTimerPill: View {
    let endDate: Date
    let action: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let remainingSeconds = remainingSeconds(at: timeline.date)

            Button(action: action) {
                Label {
                    Text(formattedTime(for: remainingSeconds))
                        .font(.subheadline.monospacedDigit().weight(.medium))
                } icon: {
                    Image(systemName: "timer")
                        .font(.subheadline.weight(.medium))
                        .symbolRenderingMode(.hierarchical)
                }
                .padding(.horizontal, 13)
                .frame(minHeight: 44)
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .liquidGlass(in: Capsule())
            .accessibilityLabel("Free session timer")
            .accessibilityValue(accessibilityValue(for: remainingSeconds))
            .accessibilityHint("Shows free session timer details.")
        }
    }

    private func remainingSeconds(at date: Date) -> Int {
        max(0, Int(ceil(endDate.timeIntervalSince(date))))
    }

    private func formattedTime(for totalSeconds: Int) -> String {
        String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    private func accessibilityValue(for totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        let secondUnit = seconds == 1 ? "second" : "seconds"

        if minutes > 0 {
            let minuteUnit = minutes == 1 ? "minute" : "minutes"
            return "\(minutes) \(minuteUnit), \(seconds) \(secondUnit) remaining"
        }

        return "\(seconds) \(secondUnit) remaining"
    }
}
