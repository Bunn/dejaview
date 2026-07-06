import SwiftUI

struct OnboardingBulletRow: View {
    let bullet: OnboardingBullet

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text(bullet.title)
                    .font(.headline)

                Text(bullet.detail)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } icon: {
            Image(systemName: bullet.systemImage)
                .font(.title3)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 34)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(cornerRadius: 20)
        .accessibilityElement(children: .combine)
    }
}
