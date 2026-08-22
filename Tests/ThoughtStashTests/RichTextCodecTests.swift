import AppKit
import XCTest
@testable import ThoughtStash

final class RichTextCodecTests: XCTestCase {
    func testRTFRoundTripPreservesBoldAndItalicTraits() throws {
        let value = NSMutableAttributedString(string: "Bold Italic")
        value.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: 14), range: NSRange(location: 0, length: 4))
        let italic = NSFontManager.shared.convert(NSFont.systemFont(ofSize: 14), toHaveTrait: .italicFontMask)
        value.addAttribute(.font, value: italic, range: NSRange(location: 5, length: 6))

        let data = try XCTUnwrap(RichTextCodec.rtfData(from: value))
        let decoded = try XCTUnwrap(RichTextCodec.attributedString(fromRTF: data))
        let boldFont = try XCTUnwrap(decoded.attribute(.font, at: 1, effectiveRange: nil) as? NSFont)
        let italicFont = try XCTUnwrap(decoded.attribute(.font, at: 7, effectiveRange: nil) as? NSFont)

        XCTAssertTrue(NSFontManager.shared.traits(of: boldFont).contains(.boldFontMask))
        XCTAssertTrue(NSFontManager.shared.traits(of: italicFont).contains(.italicFontMask))
    }

    func testMarkdownProducesAttributedFormatting() {
        let value = RichTextCodec.attributedString(fromMarkdown: "**Bold** and *italic*")

        XCTAssertEqual(value.string, "Bold and italic")
        XCTAssertNotNil(value.attribute(.font, at: 1, effectiveRange: nil))
        XCTAssertNotNil(value.attribute(.font, at: 10, effectiveRange: nil))
    }
}
