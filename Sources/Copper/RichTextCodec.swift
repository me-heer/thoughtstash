import AppKit
import Foundation

enum RichTextCodec {
    static func capturedContent(from pasteboard: NSPasteboard, excluding marker: String) -> CapturedContent? {
        guard let text = pasteboard.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty,
              text != marker else { return nil }

        if let rtf = pasteboard.data(forType: .rtf), attributedString(fromRTF: rtf) != nil {
            return CapturedContent(text: text, richTextRTF: rtf)
        }
        if let html = pasteboard.data(forType: .html),
           let attributed = attributedString(fromHTML: html),
           let rtf = rtfData(from: attributed) {
            return CapturedContent(text: text, richTextRTF: rtf)
        }
        return CapturedContent(text: text, richTextRTF: nil)
    }

    static func attributedString(fromRTF data: Data) -> NSAttributedString? {
        try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        )
    }

    static func attributedString(fromHTML data: Data) -> NSAttributedString? {
        try? NSAttributedString(
            data: data,
            options: [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue,
            ],
            documentAttributes: nil
        )
    }

    static func attributedString(fromMarkdown markdown: String) -> NSAttributedString {
        guard let attributed = try? AttributedString(markdown: markdown) else {
            return NSAttributedString(string: markdown)
        }

        let output = NSMutableAttributedString()
        for run in attributed.runs {
            let runText = String(attributed[run.range].characters)
            let range = NSRange(location: output.length, length: (runText as NSString).length)
            output.append(NSAttributedString(string: runText, attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.systemFontSize),
            ]))

            if let intent = run.inlinePresentationIntent {
                var traits: NSFontTraitMask = []
                if intent.contains(.stronglyEmphasized) { traits.insert(.boldFontMask) }
                if intent.contains(.emphasized) { traits.insert(.italicFontMask) }
                if !traits.isEmpty {
                    let font = NSFontManager.shared.convert(
                        NSFont.systemFont(ofSize: NSFont.systemFontSize),
                        toHaveTrait: traits
                    )
                    output.addAttribute(.font, value: font, range: range)
                }
            }
            if let link = run.link { output.addAttribute(.link, value: link, range: range) }
        }
        return output
    }

    static func attributedString(for note: CopperNote) -> NSAttributedString {
        if let data = note.richTextRTF, let richText = attributedString(fromRTF: data) {
            return richText
        }
        return attributedString(fromMarkdown: note.text)
    }

    static func rtfData(from attributedString: NSAttributedString) -> Data? {
        try? attributedString.data(
            from: NSRange(location: 0, length: attributedString.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
    }

    static func mergedRTF(notes: [CopperNote], asList: Bool) -> Data? {
        let output = NSMutableAttributedString()
        for (index, note) in notes.enumerated() {
            if index > 0 { output.append(NSAttributedString(string: "\n\n")) }
            if asList { output.append(NSAttributedString(string: "\(index + 1). ")) }
            output.append(attributedString(for: note))
        }
        return rtfData(from: output)
    }
}

struct CapturedContent {
    let text: String
    let richTextRTF: Data?
}
