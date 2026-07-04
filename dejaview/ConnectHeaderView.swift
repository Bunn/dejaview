import SwiftUI

struct ConnectHeaderView: View {
    let section: ConnectSection

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(section.title, systemImage: section.systemImage)
                .font(.title2.bold())
                .symbolRenderingMode(.hierarchical)

            Text(section.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
