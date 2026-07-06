import RevenueCat
import RevenueCatUI
import SwiftUI

struct RevenueCatPaywallSheet: View {
    @Environment(SubscriptionStore.self) private var subscriptionStore

    var body: some View {
        if Purchases.isConfigured {
            PaywallView()
                .task {
                    await subscriptionStore.refresh()
                }
        } else {
            RevenueCatUnavailableView()
        }
    }
}
