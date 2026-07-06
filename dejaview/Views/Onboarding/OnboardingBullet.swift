import Foundation

struct OnboardingBullet: Identifiable {
    let systemImage: String
    let title: String
    let detail: String

    var id: String {
        title
    }
}
