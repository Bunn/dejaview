import Foundation
import RevenueCat

enum RevenueCatConfiguration {
    private static let apiKeyInfoKey = "RevenueCatAPIKey"

    static func configure() {
        guard !Purchases.isConfigured else { return }

        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: apiKeyInfoKey) as? String else {
            AppLog.subscriptions.error("RevenueCat API key is missing from Info.plist")
            return
        }

        let trimmedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAPIKey.isEmpty, !trimmedAPIKey.hasPrefix("$(") else {
            AppLog.subscriptions.error("RevenueCat API key build setting is empty")
            return
        }

        #if DEBUG
        Purchases.logLevel = .debug
        #else
        Purchases.logLevel = .warn
        #endif

        Purchases.configure(withAPIKey: trimmedAPIKey)
        AppLog.subscriptions.info("RevenueCat configured")
    }
}
