import AppKit
import XCTest
@testable import ThoughtStash

final class ShortcutMapTests: XCTestCase {
    func testCommandBackspaceMatchesDeleteSelectedWithoutCharacters() {
        let entry = ShortcutMap.matchingEntry(
            keyCode: 51,
            charactersIgnoringModifiers: nil,
            modifierFlags: .command
        )

        XCTAssertEqual(entry?.slug, "deleteSelected")
    }

    func testCommandForwardDeleteMatchesDeleteSelectedWithoutCharacters() {
        let entry = ShortcutMap.matchingEntry(
            keyCode: 117,
            charactersIgnoringModifiers: nil,
            modifierFlags: .command
        )

        XCTAssertEqual(entry?.slug, "deleteSelected")
    }

    func testCommandEStillMatchesByCharacter() {
        let entry = ShortcutMap.matchingEntry(
            keyCode: 14,
            charactersIgnoringModifiers: "e",
            modifierFlags: .command
        )

        XCTAssertEqual(entry?.slug, "editSelected")
    }

    func testVimNavigationMatchesCommandJAndK() {
        let next = ShortcutMap.matchingEntry(
            keyCode: 38,
            charactersIgnoringModifiers: "j",
            modifierFlags: .command
        )
        let previous = ShortcutMap.matchingEntry(
            keyCode: 40,
            charactersIgnoringModifiers: "k",
            modifierFlags: .command
        )

        XCTAssertEqual(next?.slug, "vimSelectNext")
        XCTAssertEqual(previous?.slug, "vimSelectPrevious")
    }
}
