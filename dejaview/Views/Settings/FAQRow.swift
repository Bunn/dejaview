import SwiftUI

struct FAQRow: View {
    let item: SettingsFAQItem

    var body: some View {
        DisclosureGroup {
            Text(item.answer)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
        } label: {
            Text(item.question)
        }
    }
}
