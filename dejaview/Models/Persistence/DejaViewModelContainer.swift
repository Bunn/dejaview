import SwiftData

enum DejaViewModelContainer {
    static let cloudKitContainerIdentifier = "iCloud.dev.bunn.dejaview"

    static let shared: ModelContainer = {
        let schema = Schema([
            SavedMachineRecord.self,
            ConnectionHistoryRecord.self
        ])
        let configuration = ModelConfiguration("DejaView",
                                               schema: schema,
                                               cloudKitDatabase: .private(cloudKitContainerIdentifier))

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            AppLog.storage.fault("Failed to create SwiftData model container: \(error.localizedDescription, privacy: .public)")
            fatalError("Failed to create SwiftData model container: \(error.localizedDescription)")
        }
    }()
}
