import AppKit
import SwiftUI
import XCTest
@testable import ThoughtStash

@MainActor
final class LiveMarkdownEditorTests: XCTestCase {
    func testAppliesHeadingAndInlineEmphasisStylesWithoutChangingSource() throws {
        var value = "# Heading\nThis is **bold** and *italic*."
        let binding = Binding(get: { value }, set: { value = $0 })
        let coordinator = LiveMarkdownEditor.Coordinator(text: binding, focusRequest: UUID())
        let textView = NSTextView()
        textView.string = value

        coordinator.applyMarkdownStyles(to: textView)

        XCTAssertEqual(textView.string, value)
        let storage = try XCTUnwrap(textView.textStorage)
        let headingFont = try XCTUnwrap(storage.attribute(.font, at: 2, effectiveRange: nil) as? NSFont)
        XCTAssertEqual(headingFont.pointSize, 27)

        let source = value as NSString
        let boldRange = source.range(of: "bold")
        let boldFont = try XCTUnwrap(
            storage.attribute(.font, at: boldRange.location, effectiveRange: nil) as? NSFont
        )
        XCTAssertTrue(NSFontManager.shared.traits(of: boldFont).contains(.boldFontMask))

        let italicRange = source.range(of: "italic")
        let italicFont = try XCTUnwrap(
            storage.attribute(.font, at: italicRange.location, effectiveRange: nil) as? NSFont
        )
        XCTAssertTrue(NSFontManager.shared.traits(of: italicFont).contains(.italicFontMask))
    }
}
