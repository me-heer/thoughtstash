import AppKit
import XCTest
@testable import Copper

@MainActor
final class ComposerMarkdownEditorTests: XCTestCase {
    func testShiftReturnInsertsNewlineWithoutSubmitting() throws {
        let textView = ComposerMarkdownTextView()
        textView.string = "first line"
        textView.setSelectedRange(NSRange(location: textView.string.utf16.count, length: 0))
        var submitted = false
        textView.onSubmit = { submitted = true }

        textView.keyDown(with: try returnEvent(modifiers: .shift))

        XCTAssertEqual(textView.string, "first line\n")
        XCTAssertFalse(submitted)
    }

    func testReturnSubmitsWithoutChangingText() throws {
        let textView = ComposerMarkdownTextView()
        textView.string = "a note"
        var submitted = false
        textView.onSubmit = { submitted = true }

        textView.keyDown(with: try returnEvent(modifiers: []))

        XCTAssertEqual(textView.string, "a note")
        XCTAssertTrue(submitted)
    }

    private func returnEvent(modifiers: NSEvent.ModifierFlags) throws -> NSEvent {
        try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "\r",
            charactersIgnoringModifiers: "\r",
            isARepeat: false,
            keyCode: 36
        ))
    }
}
