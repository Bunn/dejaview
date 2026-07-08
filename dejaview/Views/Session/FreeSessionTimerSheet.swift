import SwiftUI

struct FreeSessionTimerSheet: View {
    let endDate: Date?
    let purchase: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "timer")
                .font(.system(size: 40))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.blue)

            VStack(spacing: 8) {
                Text("Free Session Timer")
                    .font(.title2.bold())

                Text("Free sessions are timed. Upgrade to Pro to keep this session active.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let endDate {
                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    let remainingSeconds = remainingSeconds(until: endDate,
                                                            at: timeline.date)

                    Text(formattedTime(for: remainingSeconds))
                        .font(.largeTitle.monospacedDigit().bold())
                        .contentTransition(.numericText())
                        .accessibilityLabel("Time remaining")
                        .accessibilityValue(accessibilityValue(for: remainingSeconds))
                }
            }

            VStack(spacing: 12) {
                Button(action: purchase) {
                    Label("Purchase Pro", systemImage: "creditcard")
                        .frame(maxWidth: .infinity)
                }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)

                Button(action: dismiss.callAsFunction) {
                    Label("Continue Free Session", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                    .buttonStyle(.glass)
                    .controlSize(.large)
            }
            .frame(maxWidth: 320)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 22)
        .frame(maxWidth: 420)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func remainingSeconds(until endDate: Date, at date: Date) -> Int {
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
