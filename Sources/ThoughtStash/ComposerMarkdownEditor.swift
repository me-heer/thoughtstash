import AppKit
import SwiftUI

struct ComposerMarkdownEditor: NSViewRepresentable {
    @Binding var text: String
    let focusRequest: UUID
    var fontTheme: AppFontTheme = .sans
    let onFocusChange: (Bool) -> Void
    let onSubmit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = ComposerMarkdownScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = false

        let textView = ComposerMarkdownTextView()
        textView.delegate = context.coordinator
        textView.onSubmit = onSubmit
        textView.onFocusChange = onFocusChange
        textView.string = text
        textView.drawsBackground = false
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.textContainerInset = NSSize(width: 1, height: 1)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.frame = NSRect(x: 0, y: 0, width: 300, height: 48)
        textView.autoresizingMask = [.width]
        context.coordinator.applyStyles(to: textView)
        scrollView.documentView = textView

        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
        }
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? ComposerMarkdownTextView else { return }
        context.coordinator.parent = self
        textView.onSubmit = onSubmit
        textView.onFocusChange = onFocusChange
        if context.coordinator.fontTheme != fontTheme {
            context.coordinator.fontTheme = fontTheme
            context.coordinator.applyStyles(to: textView)
        }
        if textView.string != text {
            let selection = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selection
            context.coordinator.applyStyles(to: textView)
        }
        if context.coordinator.focusRequest != focusRequest {
            context.coordinator.focusRequest = focusRequest
            DispatchQueue.main.async { textView.window?.makeFirstResponder(textView) }
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ComposerMarkdownEditor
        var focusRequest: UUID
        private let styler: LiveMarkdownEditor.Coordinator

        var fontTheme: AppFontTheme {
            get { styler.fontTheme }
            set { styler.fontTheme = newValue }
        }

        init(parent: ComposerMarkdownEditor) {
            self.parent = parent
            focusRequest = parent.focusRequest
            styler = LiveMarkdownEditor.Coordinator(
                text: .constant(""),
                focusRequest: UUID(),
                baseFontSize: 14,
                fontTheme: parent.fontTheme
            )
        }

        func textDidBeginEditing(_ notification: Notification) {
            parent.onFocusChange(true)
        }

        func textDidEndEditing(_ notification: Notification) {
            parent.onFocusChange(false)
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            applyStyles(to: textView)
        }

        func applyStyles(to textView: NSTextView) {
            styler.applyMarkdownStyles(to: textView)
        }
    }
}

final class ComposerMarkdownScrollView: NSScrollView {
    override func layout() {
        super.layout()
        guard let textView = documentView as? NSTextView else { return }
        let width = max(contentSize.width, 1)
        textView.setFrameSize(NSSize(width: width, height: max(textView.frame.height, contentSize.height)))
        textView.textContainer?.containerSize = NSSize(
            width: width,
            height: CGFloat.greatestFiniteMagnitude
        )
    }
}

final class ComposerMarkdownTextView: NSTextView {
    var onSubmit: (() -> Void)?
    /// Reported on first-responder changes, not just on editing, so the focus
    /// ring lights as soon as the composer is focused — including the
    /// programmatic focus Thought Stash takes on show and after a save.
    var onFocusChange: ((Bool) -> Void)?

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted { onFocusChange?(true) }
        return accepted
    }

    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned { onFocusChange?(false) }
        return resigned
    }

    override func keyDown(with event: NSEvent) {
        guard event.keyCode == 36 || event.keyCode == 76 else {
            super.keyDown(with: event)
            return
        }
        if event.modifierFlags.contains(.shift) {
            insertNewline(nil)
        } else {
            onSubmit?()
        }
    }
}
