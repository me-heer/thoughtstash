import XCTest
@testable import ThoughtStash

final class NoteSelectionTests: XCTestCase {
    private let notes = (0..<4).map { _ in UUID() }

    func testSteppingDownFromTheLastNoteFocusesTheComposer() {
        let state = NoteSelectionState.single(notes[3])

        let outcome = NoteSelection.moving(state, by: 1, extending: false, in: notes)

        XCTAssertEqual(outcome, .focusComposer)
    }

    func testSteppingDownFromAnyOtherNoteStaysInTheList() {
        let outcome = NoteSelection.moving(.single(notes[2]), by: 1, extending: false, in: notes)

        XCTAssertEqual(outcome, .selection(.single(notes[3])))
    }

    func testSteppingUpFromTheFirstNoteClampsInsteadOfLeaving() {
        let outcome = NoteSelection.moving(.single(notes[0]), by: -1, extending: false, in: notes)

        XCTAssertEqual(outcome, .selection(.single(notes[0])))
    }

    func testEnteringAnUnselectedListFromEitherEnd() {
        XCTAssertEqual(
            NoteSelection.moving(.empty, by: 1, extending: false, in: notes),
            .selection(.single(notes[0]))
        )
        XCTAssertEqual(
            NoteSelection.moving(.empty, by: -1, extending: false, in: notes),
            .selection(.single(notes[3]))
        )
    }

    func testExtendingSelectsTheRangeBetweenAnchorAndCursor() {
        var state = NoteSelectionState.single(notes[1])

        guard case .selection(let first) = NoteSelection.moving(state, by: 1, extending: true, in: notes) else {
            return XCTFail("expected a selection")
        }
        XCTAssertEqual(first.selected, Set([notes[1], notes[2]]))
        XCTAssertEqual(first.cursor, notes[2])
        XCTAssertEqual(first.anchor, notes[1])

        state = first
        guard case .selection(let second) = NoteSelection.moving(state, by: 1, extending: true, in: notes) else {
            return XCTFail("expected a selection")
        }
        XCTAssertEqual(second.selected, Set([notes[1], notes[2], notes[3]]))
        XCTAssertEqual(second.anchor, notes[1], "the anchor stays put while the cursor travels")
    }

    func testExtendingBackTowardsTheAnchorShrinksTheRange() {
        let grown = NoteSelectionState(
            selected: Set([notes[1], notes[2], notes[3]]),
            cursor: notes[3],
            anchor: notes[1]
        )

        guard case .selection(let shrunk) = NoteSelection.moving(grown, by: -1, extending: true, in: notes) else {
            return XCTFail("expected a selection")
        }
        XCTAssertEqual(shrunk.selected, Set([notes[1], notes[2]]))
        XCTAssertEqual(shrunk.cursor, notes[2])
    }

    func testExtendingPastTheAnchorFlipsTheRangeWithoutMovingTheAnchor() {
        let state = NoteSelectionState.single(notes[2])

        guard case .selection(let up) = NoteSelection.moving(state, by: -1, extending: true, in: notes) else {
            return XCTFail("expected a selection")
        }
        XCTAssertEqual(up.selected, Set([notes[1], notes[2]]))

        guard case .selection(let further) = NoteSelection.moving(up, by: -1, extending: true, in: notes) else {
            return XCTFail("expected a selection")
        }
        XCTAssertEqual(further.selected, Set([notes[0], notes[1], notes[2]]))
        XCTAssertEqual(further.anchor, notes[2])
    }

    func testExtendingFromTheLastNoteDoesNotLeaveTheList() {
        let outcome = NoteSelection.moving(.single(notes[3]), by: 1, extending: true, in: notes)

        XCTAssertEqual(outcome, .selection(.single(notes[3])))
    }

    func testAnEmptyListIsLeftAlone() {
        let outcome = NoteSelection.moving(.empty, by: 1, extending: false, in: [])

        XCTAssertEqual(outcome, .selection(.empty))
    }
}
