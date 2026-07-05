import SwiftUI
import UIKit

/// Native text field for credential entry with keyboard prediction and
/// input-assistant shortcuts disabled. This avoids repeated QuickType
/// accessory layout churn while typing username/password values.
struct CredentialTextField: UIViewRepresentable {
    let placeholder: String
    @Binding var text: String
    let isSecure: Bool

    init(_ placeholder: String, text: Binding<String>, isSecure: Bool = false) {
        self.placeholder = placeholder
        _text = text
        self.isSecure = isSecure
    }

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField(frame: .zero)
        textField.delegate = context.coordinator
        textField.addTarget(context.coordinator,
                            action: #selector(Coordinator.textDidChange(_:)),
                            for: .editingChanged)
        configure(textField)
        return textField
    }

    func updateUIView(_ textField: UITextField, context: Context) {
        context.coordinator.parent = self

        if textField.text != text {
            textField.text = text
        }

        configure(textField)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    private func configure(_ textField: UITextField) {
        textField.placeholder = placeholder
        textField.isSecureTextEntry = isSecure
        textField.font = .preferredFont(forTextStyle: .body)
        textField.adjustsFontForContentSizeCategory = true
        textField.borderStyle = .none
        textField.clearButtonMode = .whileEditing

        textField.keyboardType = .asciiCapable
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.spellCheckingType = .no
        textField.smartDashesType = .no
        textField.smartQuotesType = .no
        textField.smartInsertDeleteType = .no
        textField.textContentType = nil

        textField.inlinePredictionType = .no

        textField.inputAssistantItem.leadingBarButtonGroups = []
        textField.inputAssistantItem.trailingBarButtonGroups = []
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: CredentialTextField

        init(parent: CredentialTextField) {
            self.parent = parent
        }

        @objc func textDidChange(_ textField: UITextField) {
            parent.text = textField.text ?? ""
        }
    }
}
