import AppKit
import SwiftUI

struct LiveMarkdownEditor: NSViewRepresentable {
    @Binding var text: String
    let focusRequest: UUID
    var fontTheme: AppFontTheme = .sans
    /// Distraction-free options. The defaults are the sheet editor's existing behaviour,
    /// so ordinary call sites never mention them.
    var fontSize: CGFloat = 16
    var inset = NSSize(width: 18, height: 18)
    /// Fades every block but the one holding the caret.
    var dimsUnfocusedText = false
    /// Keeps the caret parked at a fixed height instead of letting it walk to the bottom.
    var typewriter = false

    func makeCoordinator() -> Coordinator {
        Coordinator(
            text: $text,
            focusRequest: focusRequest,
            baseFontSize: fontSize,
            fontTheme: fontTheme,
            dimsUnfocusedText: dimsUnfocusedText,
            typewriter: typewriter
        )
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
        textView.textContainerInset = inset
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

        if typewriter {
            // Room to scroll past the last line, so the caret can stay parked mid-window
            // even while writing the final paragraph.
            scrollView.automaticallyAdjustsContentInsets = false
            scrollView.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 320, right: 0)
            scrollView.hasVerticalScroller = false
        }

        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
        }
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        context.coordinator.text = $text
        if context.coordinator.fontTheme != fontTheme {
            context.coordinator.fontTheme = fontTheme
            context.coordinator.applyMarkdownStyles(to: textView)
        }
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
        var fontTheme: AppFontTheme
        private let baseFontSize: CGFloat
        private let dimsUnfocusedText: Bool
        private let typewriter: Bool
        /// Restyling re-asserts the selection, which re-enters this coordinator through
        /// `textViewDidChangeSelection`. One flag is cheaper than untangling that.
        private var isRestyling = false

        init(
            text: Binding<String>,
            focusRequest: UUID,
            baseFontSize: CGFloat = 16,
            fontTheme: AppFontTheme = .sans,
            dimsUnfocusedText: Bool = false,
            typewriter: Bool = false
        ) {
            self.text = text
            self.focusRequest = focusRequest
            self.baseFontSize = baseFontSize
            self.fontTheme = fontTheme
            self.dimsUnfocusedText = dimsUnfocusedText
            self.typewriter = typewriter
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
            applyMarkdownStyles(to: textView)
            pinCaret(in: textView)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard !isRestyling, let textView = notification.object as? NSTextView else { return }
            if dimsUnfocusedText { applyMarkdownStyles(to: textView) }
            pinCaret(in: textView)
        }

        /// Holds the caret at a fixed fraction of the window instead of scrolling only
        /// once it reaches the bottom edge.
        private func pinCaret(in textView: NSTextView) {
            guard typewriter,
                  let scrollView = textView.enclosingScrollView,
                  let layoutManager = textView.layoutManager,
                  let container = textView.textContainer else { return }
            let glyphRange = layoutManager.glyphRange(
                forCharacterRange: textView.selectedRange(),
                actualCharacterRange: nil
            )
            var caret = layoutManager.boundingRect(forGlyphRange: glyphRange, in: container)
            caret.origin.y += textView.textContainerInset.height
            let clip = scrollView.contentView
            let visibleHeight = clip.bounds.height
            let bottomRoom = scrollView.contentInsets.bottom
            let maxOffset = max(0, textView.bounds.height + bottomRoom - visibleHeight)
            let target = min(max(0, caret.midY - visibleHeight * 0.42), maxOffset)
            guard abs(clip.bounds.origin.y - target) > 0.5 else { return }
            clip.scroll(to: NSPoint(x: clip.bounds.origin.x, y: target))
            scrollView.reflectScrolledClipView(clip)
        }

        /// The block the caret sits in: consecutive non-blank lines, so a list or a
        /// wrapped paragraph stays lit as one unit rather than one line at a time.
        static func focusedBlockRange(in source: NSString, selection: NSRange) -> NSRange {
            guard source.length > 0 else { return NSRange(location: 0, length: 0) }
            let clamped = NSRange(
                location: min(selection.location, source.length),
                length: min(selection.length, source.length - min(selection.location, source.length))
            )
            var block = source.paragraphRange(for: clamped)
            func isBlank(_ range: NSRange) -> Bool {
                source.substring(with: range).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            while block.location > 0 {
                let previous = source.paragraphRange(for: NSRange(location: block.location - 1, length: 0))
                if isBlank(previous) { break }
                block = NSRange(location: previous.location, length: NSMaxRange(block) - previous.location)
            }
            while NSMaxRange(block) < source.length {
                let next = source.paragraphRange(for: NSRange(location: NSMaxRange(block), length: 0))
                if isBlank(next) { break }
                block = NSRange(location: block.location, length: NSMaxRange(next) - block.location)
            }
            return block
        }

        private func dimText(in storage: NSMutableAttributedString, outside focus: NSRange) {
            let full = NSRange(location: 0, length: storage.length)
            // Collected first, applied after: mutating the attribute being enumerated
            // inside the enumeration is undefined.
            var dimmed: [(NSRange, NSColor)] = []
            storage.enumerateAttribute(.foregroundColor, in: full, options: []) { value, range, _ in
                guard let color = value as? NSColor else { return }
                let beforeEnd = min(NSMaxRange(range), focus.location)
                let afterStart = max(range.location, NSMaxRange(focus))
                for gap in [
                    NSRange(location: range.location, length: max(0, beforeEnd - range.location)),
                    NSRange(location: afterStart, length: max(0, NSMaxRange(range) - afterStart)),
                ] where gap.length > 0 {
                    dimmed.append((gap, color.withAlphaComponent(0.24)))
                }
            }
            for (range, color) in dimmed {
                storage.addAttribute(.foregroundColor, value: color, range: range)
            }
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            let isNewline = commandSelector == #selector(NSResponder.insertNewline(_:))
                || commandSelector == #selector(NSResponder.insertNewlineIgnoringFieldEditor(_:))
            guard isNewline,
                  textView.selectedRange().length == 0,
                  let edit = Self.listContinuation(
                    in: textView.string,
                    cursorLocation: textView.selectedRange().location
                  ) else { return false }

            guard textView.shouldChangeText(in: edit.replacementRange, replacementString: edit.text) else {
                return true
            }
            textView.replaceCharacters(in: edit.replacementRange, with: edit.text)
            textView.didChangeText()
            return true
        }

        struct ListContinuation: Equatable {
            let replacementRange: NSRange
            let text: String
        }

        static func listContinuation(in text: String, cursorLocation: Int) -> ListContinuation? {
            let source = text as NSString
            guard cursorLocation >= 0, cursorLocation <= source.length else { return nil }
            let lineRange = source.lineRange(for: NSRange(location: cursorLocation, length: 0))
            let lengthBeforeCursor = cursorLocation - lineRange.location
            let prefix = source.substring(with: NSRange(location: lineRange.location, length: lengthBeforeCursor))

            let pattern = #"^(\s*)(?:(\d+)\.\s|(\- |\* |\+ ))(.*)$"#
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(
                    in: prefix,
                    range: NSRange(location: 0, length: (prefix as NSString).length)
                  ) else { return nil }

            let indent = (prefix as NSString).substring(with: match.range(at: 1))
            let content = (prefix as NSString).substring(with: match.range(at: 4))
            if content.trimmingCharacters(in: .whitespaces).isEmpty {
                return ListContinuation(
                    replacementRange: NSRange(location: lineRange.location, length: lengthBeforeCursor),
                    text: ""
                )
            }

            let marker: String
            if match.range(at: 2).location != NSNotFound {
                let number = Int((prefix as NSString).substring(with: match.range(at: 2))) ?? 0
                marker = "\(number + 1). "
            } else {
                marker = (prefix as NSString).substring(with: match.range(at: 3))
            }
            return ListContinuation(
                replacementRange: NSRange(location: cursorLocation, length: 0),
                text: "\n\(indent)\(marker)"
            )
        }

        func applyMarkdownStyles(to textView: NSTextView) {
            guard let storage = textView.textStorage else { return }
            let selection = textView.selectedRanges
            let visibleOrigin = textView.enclosingScrollView?.contentView.bounds.origin
            let fullRange = NSRange(location: 0, length: storage.length)
            let baseFont = fontTheme.nsFont(size: baseFontSize)
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
            if dimsUnfocusedText {
                dimText(
                    in: storage,
                    outside: Self.focusedBlockRange(
                        in: storage.string as NSString,
                        selection: textView.selectedRange()
                    )
                )
            }
            storage.endEditing()
            isRestyling = true
            defer { isRestyling = false }
            if textView.selectedRanges != selection {
                textView.selectedRanges = selection
            }
            if let visibleOrigin,
               let clipView = textView.enclosingScrollView?.contentView,
               clipView.bounds.origin != visibleOrigin {
                clipView.scroll(to: visibleOrigin)
                textView.enclosingScrollView?.reflectScrolledClipView(clipView)
            }
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
                        value: self.fontTheme.nsFont(size: size, weight: .semibold),
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
                storage.addAttribute(.font, value: self.fontTheme.nsFont(size: baseFont.pointSize, weight: .bold), range: content)
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
