import RevenueCat
import RevenueCatUI
import SwiftUI

struct RevenueCatCustomerCenterSheet: View {
    @Environment(SubscriptionStore.self) private var subscriptionStore

    var body: some View {
        if Purchases.isConfigured {
            CustomerCenterView()
                .onCustomerCenterRestoreCompleted { customerInfo in
                    subscriptionStore.apply(customerInfo)
                }
                .onDisappear {
                    Task {
                        await subscriptionStore.refresh()
                    }
                }
        } else {
            RevenueCatUnavailableView()
        }
    }
}
