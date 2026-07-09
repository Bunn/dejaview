import SwiftUI

struct RecentConnectionsView: View {
    let entries: [ConnectionHistoryEntry]
    let isSearching: Bool
    let canReconnectDirectly: (ConnectionHistoryEntry) -> Bool
    let connect: (ConnectionHistoryEntry) -> Void
    let delete: (ConnectionHistoryEntry) -> Void

    var body: some View {
        if entries.isEmpty {
            if isSearching {
                ContentUnavailableView.search
            } else {
                ContentUnavailableView("No Recent Sessions",
                                       systemImage: "clock.arrow.circlepath",
                                       description: Text("Sessions appear here after a connection succeeds."))
                    .padding(24)
                    .frame(maxWidth: .infinity)
                    .glassPanel(cornerRadius: 28)
            }
        } else {
            GlassEffectContainer(spacing: 16) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 16, alignment: .top)],
                          alignment: .leading,
                          spacing: 16) {
                    ForEach(entries) { entry in
                        RecentConnectionTile(entry: entry,
                                             canReconnectDirectly: canReconnectDirectly(entry)) {
                            connect(entry)
                        } delete: {
                            delete(entry)
                        }
                    }
                }
            }
        }
    }
}
