import SwiftUI

/// A session input field whose Return key submits without resigning focus.
struct RemoteSessionTextField: UIViewRepresentable {
    let placeholder: String
    @Binding var text: String
    @Binding var isFocused: Bool
    let onSubmit: () -> Void

    init(_ placeholder: String,
         text: Binding<String>,
         isFocused: Binding<Bool>,
         onSubmit: @escaping () -> Void) {
        self.placeholder = placeholder
        _text = text
        _isFocused = isFocused
        self.onSubmit = onSubmit
    }

    func makeUIView(context: Context) -> TextField {
        let textField = TextField(frame: .zero)
        textField.delegate = context.coordinator
        textField.addTarget(context.coordinator,
                            action: #selector(Coordinator.textDidChange(_:)),
                            for: .editingChanged)
        configure(textField)
        return textField
    }

    func updateUIView(_ textField: TextField, context: Context) {
        context.coordinator.parent = self

        if textField.text != text {
            textField.text = text
        }

        configure(textField)
        textField.setFocused(isFocused)
    }

    func sizeThatFits(_ proposal: ProposedViewSize,
                      uiView textField: TextField,
                      context: Context) -> CGSize? {
        let intrinsicSize = textField.intrinsicContentSize
        let proposedWidth = proposal.width.flatMap { $0.isFinite ? $0 : nil }

        return CGSize(width: proposedWidth ?? intrinsicSize.width,
                      height: intrinsicSize.height)
    }

    static func dismantleUIView(_ textField: TextField, coordinator: Coordinator) {
        textField.setFocused(false)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    private func configure(_ textField: TextField) {
        textField.placeholder = placeholder
        textField.font = .preferredFont(forTextStyle: .body)
        textField.adjustsFontForContentSizeCategory = true
        textField.borderStyle = .none
        textField.backgroundColor = .clear
        textField.textColor = .label
        textField.tintColor = .tintColor
        textField.setContentHuggingPriority(.required, for: .vertical)
        textField.setContentCompressionResistancePriority(.required, for: .vertical)

        textField.keyboardAppearance = .dark
        textField.keyboardType = .default
        textField.returnKeyType = .default
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.spellCheckingType = .no
        textField.smartDashesType = .no
        textField.smartQuotesType = .no
        textField.smartInsertDeleteType = .no
        textField.inlinePredictionType = .no
        textField.textContentType = nil
    }

    final class TextField: UITextField {
        private var wantsFocus = false

        override func didMoveToWindow() {
            super.didMoveToWindow()
            synchronizeFocus()
        }

        func setFocused(_ isFocused: Bool) {
            wantsFocus = isFocused
            synchronizeFocus()
        }

        private func synchronizeFocus() {
            if wantsFocus {
                guard window != nil, !isFirstResponder else { return }

                Task { @MainActor [weak self] in
                    await Task.yield()
                    guard let self, self.wantsFocus, self.window != nil else { return }
                    self.becomeFirstResponder()
                }
            } else if isFirstResponder {
                resignFirstResponder()
            }
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: RemoteSessionTextField

        init(parent: RemoteSessionTextField) {
            self.parent = parent
        }

        @objc func textDidChange(_ textField: UITextField) {
            parent.text = textField.text ?? ""
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            parent.isFocused = true
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            parent.isFocused = false
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.onSubmit()
            parent.isFocused = true
            return false
        }
    }
}
