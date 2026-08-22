import AppKit
import SwiftUI
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

    func testShiftCommandJAndKExtendTheSelection() {
        let next = ShortcutMap.matchingEntry(
            keyCode: 38,
            charactersIgnoringModifiers: "j",
            modifierFlags: [.command, .shift]
        )
        let previous = ShortcutMap.matchingEntry(
            keyCode: 40,
            charactersIgnoringModifiers: "k",
            modifierFlags: [.command, .shift]
        )

        XCTAssertEqual(next?.notification, .stashExtendSelectionNext)
        XCTAssertEqual(previous?.notification, .stashExtendSelectionPrevious)
    }

    func testShiftCommandArrowsExtendTheSelection() {
        let next = ShortcutMap.matchingEntry(
            keyCode: 125,
            charactersIgnoringModifiers: String(KeyEquivalent.downArrow.character),
            modifierFlags: [.command, .shift]
        )
        let previous = ShortcutMap.matchingEntry(
            keyCode: 126,
            charactersIgnoringModifiers: String(KeyEquivalent.upArrow.character),
            modifierFlags: [.command, .shift]
        )

        XCTAssertEqual(next?.notification, .stashExtendSelectionNext)
        XCTAssertEqual(previous?.notification, .stashExtendSelectionPrevious)
    }

    func testOptionCommandArrowsMoveBetweenSectionsInBothDirections() {
        let previous = ShortcutMap.matchingEntry(
            keyCode: 123,
            charactersIgnoringModifiers: String(KeyEquivalent.leftArrow.character),
            modifierFlags: [.command, .option]
        )
        let next = ShortcutMap.matchingEntry(
            keyCode: 124,
            charactersIgnoringModifiers: String(KeyEquivalent.rightArrow.character),
            modifierFlags: [.command, .option]
        )

        XCTAssertEqual(previous?.slug, "moveToPreviousSection")
        XCTAssertEqual(next?.slug, "moveToNextSection")
    }

    /// Two entries answering the same chord means one of them is unreachable.
    func testNoTwoBindingsShareAChord() {
        var seen: [String: String] = [:]
        for entry in ShortcutMap.all {
            guard entry.notification != nil, let key = entry.keyEquivalent else { continue }
            let chord = "\(entry.modifiers.rawValue)-\(key.character)"
            XCTAssertNil(seen[chord], "\(entry.slug) collides with \(seen[chord] ?? "") on \(entry.displayString)")
            seen[chord] = entry.slug
        }
    }
}
