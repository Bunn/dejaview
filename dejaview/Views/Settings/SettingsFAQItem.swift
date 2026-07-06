import Foundation

struct SettingsFAQItem: Identifiable {
    let question: String
    let answer: String

    var id: String {
        question
    }
}
