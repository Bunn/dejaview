import SwiftUI

/// A non-rendering input responder that forwards the system keyboard directly
/// to a remote session without keeping a local text buffer.
struct RemoteSoftwareKeyboardInput: UIViewRepresentable {
    let focusRequest: Int
    let onInsertText: (String) -> Void
    let onDeleteBackward: () -> Void
    let onReturn: () -> Void

    func makeUIView(context: Context) -> InputView {
        let inputView = InputView()
        update(inputView)
        return inputView
    }

    func updateUIView(_ inputView: InputView, context: Context) {
        update(inputView)
    }

    static func dismantleUIView(_ inputView: InputView, coordinator: Void) {
        inputView.deactivate()
    }

    private func update(_ inputView: InputView) {
        inputView.onInsertText = onInsertText
        inputView.onDeleteBackward = onDeleteBackward
        inputView.onReturn = onReturn
        inputView.requestFocus(focusRequest)
    }

    final class InputView: UIView, UIKeyInput {
        var onInsertText: (String) -> Void = { _ in }
        var onDeleteBackward: () -> Void = {}
        var onReturn: () -> Void = {}

        var autocapitalizationType: UITextAutocapitalizationType = .none
        var autocorrectionType: UITextAutocorrectionType = .no
        var spellCheckingType: UITextSpellCheckingType = .no
        var smartQuotesType: UITextSmartQuotesType = .no
        var smartDashesType: UITextSmartDashesType = .no
        var smartInsertDeleteType: UITextSmartInsertDeleteType = .no
        var inlinePredictionType: UITextInlinePredictionType = .no
        var keyboardAppearance: UIKeyboardAppearance = .dark
        var keyboardType: UIKeyboardType = .default
        var returnKeyType: UIReturnKeyType = .default

        override var canBecomeFirstResponder: Bool { true }

        // The remote insertion point may have content even though this local
        // responder does not. Returning true keeps Backspace available.
        var hasText: Bool { true }

        private var latestFocusRequest: Int?
        private var isActive = true

        override init(frame: CGRect) {
            super.init(frame: frame)
            configure()
        }

        convenience init() {
            self.init(frame: .zero)
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
            configure()
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()

            if window != nil {
                focusWhenPossible()
            } else if isFirstResponder {
                resignFirstResponder()
            }
        }

        func requestFocus(_ request: Int) {
            guard latestFocusRequest != request else { return }

            latestFocusRequest = request
            focusWhenPossible()
        }

        func deactivate() {
            isActive = false
            latestFocusRequest = nil

            if isFirstResponder {
                resignFirstResponder()
            }
        }

        func insertText(_ text: String) {
            let normalizedText = text
                .replacing("\r\n", with: "\n")
                .replacing("\r", with: "\n")
            guard !normalizedText.isEmpty else { return }

            let segments = normalizedText.split(separator: "\n", omittingEmptySubsequences: false)

            for (index, segment) in segments.enumerated() {
                if !segment.isEmpty {
                    onInsertText(String(segment))
                }

                if index < segments.count - 1 {
                    onReturn()
                }
            }
        }

        func deleteBackward() {
            onDeleteBackward()
        }

        private func configure() {
            backgroundColor = .clear
            isAccessibilityElement = false
            inputAssistantItem.leadingBarButtonGroups = []
            inputAssistantItem.trailingBarButtonGroups = []
        }

        private func focusWhenPossible() {
            guard isActive, window != nil, !isFirstResponder else { return }

            Task { @MainActor [weak self] in
                await Task.yield()
                guard let self, self.isActive, self.window != nil else { return }
                self.becomeFirstResponder()
            }
        }
    }
}
