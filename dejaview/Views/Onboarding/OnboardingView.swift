import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPage: OnboardingPage = .welcome

    let onComplete: (() -> Void)?

    init(onComplete: (() -> Void)? = nil) {
        self.onComplete = onComplete
    }

    var body: some View {
        TabView(selection: $selectedPage) {
            ForEach(OnboardingPage.allCases) { page in
                ScrollView {
                    OnboardingPageView(page: page)
                        .padding(.horizontal, 20)
                        .padding(.top, 22)
                        .padding(.bottom, 120)
                        .frame(maxWidth: .infinity)
                }
                .tag(page)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            OnboardingFooterView(selectedPage: selectedPage,
                                 completionTitle: onComplete == nil ? "Done" : "Get Started",
                                 onPrimaryButtonTapped: advanceOrComplete)
        }
        .navigationTitle("Getting Started")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if onComplete != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Skip", action: complete)
                }
            }
        }
    }

    private func advanceOrComplete() {
        if selectedPage.isLast {
            complete()
        } else {
            withAnimation {
                selectedPage = selectedPage.next
            }
        }
    }

    private func complete() {
        if let onComplete {
            onComplete()
        } else {
            dismiss()
        }
    }
}

#Preview {
    NavigationStack {
        OnboardingView()
    }
}
