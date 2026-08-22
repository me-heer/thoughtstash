import AppKit
import SwiftUI

struct LiveMarkdownEditor: NSViewRepresentable {
    @Binding var text: String
    let focusRequest: UUID

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, focusRequest: focusRequest)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.textContainerInset = NSSize(width: 18, height: 18)
        textView.textContainer?.widthTracksTextView = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.minSize = .zero
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.string = text
        context.coordinator.applyMarkdownStyles(to: textView)
        scrollView.documentView = textView

        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
        }
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        context.coordinator.text = $text
        if textView.string != text {
            let selection = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selection
            context.coordinator.applyMarkdownStyles(to: textView)
        }
        if context.coordinator.focusRequest != focusRequest {
            context.coordinator.focusRequest = focusRequest
            DispatchQueue.main.async {
                textView.window?.makeFirstResponder(textView)
            }
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var focusRequest: UUID
        private let baseFontSize: CGFloat

        init(text: Binding<String>, focusRequest: UUID, baseFontSize: CGFloat = 16) {
            self.text = text
            self.focusRequest = focusRequest
            self.baseFontSize = baseFontSize
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
            applyMarkdownStyles(to: textView)
        }

        func applyMarkdownStyles(to textView: NSTextView) {
            guard let storage = textView.textStorage else { return }
            let selection = textView.selectedRanges
            let fullRange = NSRange(location: 0, length: storage.length)
            let baseFont = NSFont.systemFont(ofSize: baseFontSize)
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = 5

            storage.beginEditing()
            storage.setAttributes([
                .font: baseFont,
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: paragraph,
            ], range: fullRange)

            styleLines(in: storage, baseFont: baseFont)
            styleInlineMarkdown(in: storage, baseFont: baseFont)
            storage.endEditing()
            textView.selectedRanges = selection
            textView.typingAttributes = [
                .font: baseFont,
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: paragraph,
            ]
        }

        private func styleLines(in storage: NSMutableAttributedString, baseFont: NSFont) {
            let source = storage.string as NSString
            var index = 0
            var inCodeBlock = false
            while index < source.length {
                let lineRange = source.lineRange(for: NSRange(location: index, length: 0))
                let line = source.substring(with: lineRange).trimmingCharacters(in: .newlines)
                let contentRange = NSRange(location: lineRange.location, length: (line as NSString).length)

                if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    inCodeBlock.toggle()
                    storage.addAttributes([
                        .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular),
                        .foregroundColor: NSColor.tertiaryLabelColor,
                    ], range: contentRange)
                } else if inCodeBlock {
                    storage.addAttributes([
                        .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular),
                        .backgroundColor: NSColor.quaternaryLabelColor.withAlphaComponent(0.12),
                    ], range: contentRange)
                } else if let heading = firstMatch(#"^(#{1,3})\s+"#, in: line) {
                    let level = heading.range(at: 1).length
                    let size: CGFloat = level == 1 ? 27 : (level == 2 ? 22 : 18)
                    storage.addAttribute(
                        .font,
                        value: NSFont.systemFont(ofSize: size, weight: .semibold),
                        range: contentRange
                    )
                    styleMarker(heading.range, lineOffset: lineRange.location, in: storage)
                } else if let marker = firstMatch(#"^\s*([-*+] |\d+\. )"#, in: line) {
                    styleMarker(marker.range(at: 1), lineOffset: lineRange.location, in: storage)
                } else if let marker = firstMatch(#"^\s*>\s+"#, in: line) {
                    storage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: contentRange)
                    styleMarker(marker.range, lineOffset: lineRange.location, in: storage)
                }
                index = NSMaxRange(lineRange)
            }
        }

        private func styleInlineMarkdown(in storage: NSMutableAttributedString, baseFont: NSFont) {
            let source = storage.string
            apply(#"\*\*([^*\n]+)\*\*|__([^_\n]+)__"#, to: source) { match in
                let content = match.range(at: 1).location != NSNotFound ? match.range(at: 1) : match.range(at: 2)
                storage.addAttribute(.font, value: NSFont.systemFont(ofSize: baseFont.pointSize, weight: .bold), range: content)
                self.styleOuterMarkers(match.range, content: content, in: storage)
            }
            apply(#"(?<!\*)\*([^*\n]+)\*(?!\*)|(?<!_)_([^_\n]+)_(?!_)"#, to: source) { match in
                let content = match.range(at: 1).location != NSNotFound ? match.range(at: 1) : match.range(at: 2)
                storage.addAttribute(
                    .font,
                    value: NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask),
                    range: content
                )
                self.styleOuterMarkers(match.range, content: content, in: storage)
            }
            apply(#"`([^`\n]+)`"#, to: source) { match in
                storage.addAttributes([
                    .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular),
                    .backgroundColor: NSColor.quaternaryLabelColor.withAlphaComponent(0.18),
                ], range: match.range(at: 1))
                self.styleOuterMarkers(match.range, content: match.range(at: 1), in: storage)
            }
        }

        private func styleOuterMarkers(
            _ fullRange: NSRange,
            content: NSRange,
            in storage: NSMutableAttributedString
        ) {
            let prefix = NSRange(location: fullRange.location, length: content.location - fullRange.location)
            let suffixStart = NSMaxRange(content)
            let suffix = NSRange(location: suffixStart, length: NSMaxRange(fullRange) - suffixStart)
            storage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: prefix)
            storage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: suffix)
        }

        private func styleMarker(
            _ range: NSRange,
            lineOffset: Int,
            in storage: NSMutableAttributedString
        ) {
            let absolute = NSRange(location: lineOffset + range.location, length: range.length)
            storage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: absolute)
        }

        private func firstMatch(_ pattern: String, in value: String) -> NSTextCheckingResult? {
            try? NSRegularExpression(pattern: pattern).firstMatch(
                in: value,
                range: NSRange(location: 0, length: (value as NSString).length)
            )
        }

        private func apply(
            _ pattern: String,
            to value: String,
            action: (NSTextCheckingResult) -> Void
        ) {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
            regex.enumerateMatches(
                in: value,
                range: NSRange(location: 0, length: (value as NSString).length)
            ) { match, _, _ in
                if let match { action(match) }
            }
        }
    }
}
