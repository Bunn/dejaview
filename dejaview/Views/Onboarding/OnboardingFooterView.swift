import SwiftUI

struct OnboardingFooterView: View {
    let selectedPage: OnboardingPage
    let completionTitle: String
    let onPrimaryButtonTapped: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            OnboardingProgressDots(selectedPage: selectedPage)

            Spacer(minLength: 12)

            Button(primaryButtonTitle,
                   systemImage: primaryButtonSystemImage,
                   action: onPrimaryButtonTapped)
                .buttonStyle(.glassProminent)
                .controlSize(.large)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.regularMaterial)
    }

    private var primaryButtonTitle: String {
        selectedPage.isLast ? completionTitle : "Continue"
    }

    private var primaryButtonSystemImage: String {
        selectedPage.isLast ? "checkmark.circle.fill" : "arrow.right.circle.fill"
    }
}
