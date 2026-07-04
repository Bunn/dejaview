import SwiftUI

struct ConnectSidebarView: View {
    @Binding var selection: ConnectSection?

    let hostCount: Int
    let nearbyCount: Int

    var body: some View {
        List(selection: $selection) {
            Section("Connect") {
                ForEach(ConnectSection.allCases) { section in
                    NavigationLink(value: section) {
                        Label(section.title, systemImage: section.systemImage)
                    }
                    .badge(badgeValue(for: section))
                }
            }
        }
        .navigationTitle("Deja View")
        .navigationSplitViewColumnWidth(min: 220, ideal: 280, max: 340)
    }

    private func badgeValue(for section: ConnectSection) -> Int {
        switch section {
        case .hosts:
            hostCount
        case .nearby:
            nearbyCount
        case .manual:
            0
        }
    }
}
