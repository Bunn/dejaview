import SwiftUI

struct OnboardingProgressDots: View {
    let selectedPage: OnboardingPage

    var body: some View {
        HStack(spacing: 8) {
            ForEach(OnboardingPage.allCases) { page in
                Circle()
                    .fill(page == selectedPage ? .primary : .tertiary)
                    .frame(width: 8, height: 8)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(selectedPage.rawValue + 1) of \(OnboardingPage.allCases.count)")
    }
}
