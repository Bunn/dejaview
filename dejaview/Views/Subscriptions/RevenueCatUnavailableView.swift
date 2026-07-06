import SwiftUI

struct RevenueCatUnavailableView: View {
    var body: some View {
        ContentUnavailableView("RevenueCat Not Configured",
                               systemImage: "exclamationmark.triangle",
                               description: Text("Set REVENUECAT_API_KEY for this build configuration before opening subscription screens."))
    }
}
