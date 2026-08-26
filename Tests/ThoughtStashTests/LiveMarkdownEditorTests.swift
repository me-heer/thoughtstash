import AppKit
import SwiftUI
import XCTest
@testable import ThoughtStash

@MainActor
final class LiveMarkdownEditorTests: XCTestCase {
    func testContinuesNumberedListWithNextNumber() throws {
        let text = "1. first item"
        let edit = try XCTUnwrap(
            LiveMarkdownEditor.Coordinator.listContinuation(
                in: text,
                cursorLocation: (text as NSString).length
            )
        )

        XCTAssertEqual(edit.replacementRange, NSRange(location: 13, length: 0))
        XCTAssertEqual(edit.text, "\n2. ")
    }

    func testContinuesIndentedBulletList() throws {
        let text = "  - first item"
        let edit = try XCTUnwrap(
            LiveMarkdownEditor.Coordinator.listContinuation(
                in: text,
                cursorLocation: (text as NSString).length
            )
        )

        XCTAssertEqual(edit.text, "\n  - ")
    }

    func testEmptyListItemEndsTheList() throws {
        let text = "1. first\n2. "
        let edit = try XCTUnwrap(
            LiveMarkdownEditor.Coordinator.listContinuation(
                in: text,
                cursorLocation: (text as NSString).length
            )
        )

        XCTAssertEqual(edit.replacementRange, NSRange(location: 9, length: 3))
        XCTAssertEqual(edit.text, "")
    }

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

    // MARK: Focus mode

    func testFocusedBlockCoversConsecutiveNonBlankLines() {
        let text = "intro line\n\n- one\n- two\n- three\n\ntail" as NSString
        let caret = text.range(of: "- two")

        let block = LiveMarkdownEditor.Coordinator.focusedBlockRange(
            in: text,
            selection: NSRange(location: caret.location, length: 0)
        )

        XCTAssertEqual(text.substring(with: block), "- one\n- two\n- three\n")
    }

    func testFocusedBlockStopsAtBlankLines() {
        let text = "first\n\nsecond" as NSString

        let block = LiveMarkdownEditor.Coordinator.focusedBlockRange(
            in: text,
            selection: NSRange(location: 0, length: 0)
        )

        XCTAssertEqual(text.substring(with: block), "first\n")
    }

    func testFocusedBlockClampsSelectionPastTheEnd() {
        let text = "only line" as NSString

        let block = LiveMarkdownEditor.Coordinator.focusedBlockRange(
            in: text,
            selection: NSRange(location: 999, length: 5)
        )

        XCTAssertEqual(text.substring(with: block), "only line")
    }
}
