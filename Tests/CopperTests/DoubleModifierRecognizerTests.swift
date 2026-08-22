import CoreGraphics
import XCTest
@testable import Copper

final class DoubleModifierRecognizerTests: XCTestCase {
    func testRecognizesTwoCompleteShiftTaps() {
        var recognizer = DoubleModifierRecognizer()

        XCTAssertFalse(recognizer.process(shift(down: true, at: 1.0), shortcut: .shift, interval: 0.42))
        XCTAssertFalse(recognizer.process(shift(down: false, at: 1.05), shortcut: .shift, interval: 0.42))
        XCTAssertFalse(recognizer.process(shift(down: true, at: 1.20), shortcut: .shift, interval: 0.42))
        XCTAssertTrue(recognizer.process(shift(down: false, at: 1.25), shortcut: .shift, interval: 0.42))
    }

    func testDoesNotRecognizeHeldShiftOrExpiredSequence() {
        var recognizer = DoubleModifierRecognizer()

        XCTAssertFalse(recognizer.process(shift(down: true, at: 1.0), shortcut: .shift, interval: 0.42))
        XCTAssertFalse(recognizer.process(sample(.flagsChanged, keyCode: 60, flags: .maskShift, at: 1.1), shortcut: .shift, interval: 0.42))
        recognizer.reset()
        XCTAssertFalse(recognizer.process(shift(down: true, at: 2.0), shortcut: .shift, interval: 0.42))
        XCTAssertFalse(recognizer.process(shift(down: false, at: 2.05), shortcut: .shift, interval: 0.42))
        XCTAssertFalse(recognizer.process(shift(down: true, at: 2.6), shortcut: .shift, interval: 0.42))
    }

    func testTypingBetweenTapsCancelsSequence() {
        var recognizer = DoubleModifierRecognizer()

        XCTAssertFalse(recognizer.process(shift(down: true, at: 1.0), shortcut: .shift, interval: 0.42))
        XCTAssertFalse(recognizer.process(shift(down: false, at: 1.05), shortcut: .shift, interval: 0.42))
        XCTAssertFalse(recognizer.process(sample(.keyDown, keyCode: 0, flags: .maskShift, at: 1.1), shortcut: .shift, interval: 0.42))
        XCTAssertFalse(recognizer.process(shift(down: true, at: 1.2), shortcut: .shift, interval: 0.42))
    }

    private func shift(down: Bool, at timestamp: TimeInterval) -> KeyboardSample {
        sample(.flagsChanged, keyCode: 56, flags: down ? .maskShift : [], at: timestamp)
    }

    private func sample(
        _ kind: KeyboardSample.Kind,
        keyCode: UInt16,
        flags: CGEventFlags,
        at timestamp: TimeInterval
    ) -> KeyboardSample {
        KeyboardSample(kind: kind, keyCode: keyCode, flags: flags, timestamp: timestamp)
    }
}
