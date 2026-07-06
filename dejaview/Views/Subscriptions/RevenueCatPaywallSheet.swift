import RevenueCat
import RevenueCatUI
import SwiftUI

struct RevenueCatPaywallSheet: View {
    @Environment(SubscriptionStore.self) private var subscriptionStore

    private let onProAccessGranted: (@MainActor @Sendable () -> Void)?

    init(onProAccessGranted: (@MainActor @Sendable () -> Void)? = nil) {
        self.onProAccessGranted = onProAccessGranted
    }

    var body: some View {
        if Purchases.isConfigured {
            PaywallView()
                .onPurchaseCompleted { customerInfo in
                    handle(customerInfo)
                }
                .onRestoreCompleted { customerInfo in
                    handle(customerInfo)
                }
                .task {
                    await subscriptionStore.refresh()
                }
        } else {
            RevenueCatUnavailableView()
        }
    }

    private func handle(_ customerInfo: CustomerInfo) {
        subscriptionStore.apply(customerInfo)

        if subscriptionStore.hasProAccess {
            onProAccessGranted?()
        }
    }
}
