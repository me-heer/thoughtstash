import CoreGraphics
import Foundation

struct KeyboardSample {
    enum Kind {
        case flagsChanged
        case keyDown
        case keyUp
    }

    let kind: Kind
    let keyCode: UInt16
    let flags: CGEventFlags
    let timestamp: TimeInterval
}

struct DoubleModifierRecognizer {
    private enum State {
        case idle
        case firstPressed(TimeInterval)
        case armed(TimeInterval)
        case latched
    }

    private var state: State = .idle
    private var pressedKeys = Set<UInt16>()

    mutating func process(
        _ sample: KeyboardSample,
        shortcut: CaptureShortcut,
        interval: TimeInterval
    ) -> Bool {
        expireSequence(at: sample.timestamp, interval: interval)

        let otherModifiers = sample.flags.rawValue & disallowedModifierMask(for: shortcut)
        if otherModifiers != 0 {
            reset()
            return false
        }

        if sample.kind == .keyDown {
            reset()
            return false
        }

        guard sample.kind == .flagsChanged,
              shortcut.keyCodes.contains(sample.keyCode) else { return false }

        let wasPressed = pressedKeys.contains(sample.keyCode)
        if wasPressed {
            pressedKeys.remove(sample.keyCode)
            guard pressedKeys.isEmpty else { return false }

            switch state {
            case .firstPressed(let firstDown):
                state = .armed(firstDown)
            case .latched:
                state = .idle
            default:
                reset()
            }
            return false
        }

        guard sample.flags.contains(shortcut.cgEventFlag) else {
            reset()
            return false
        }

        if !pressedKeys.isEmpty {
            pressedKeys.insert(sample.keyCode)
            state = .idle
            return false
        }

        pressedKeys.insert(sample.keyCode)
        switch state {
        case .idle:
            state = .firstPressed(sample.timestamp)
        case .armed(let firstDown) where sample.timestamp - firstDown <= interval:
            state = .latched
            return true
        default:
            state = .firstPressed(sample.timestamp)
        }
        return false
    }

    mutating func reset() {
        state = .idle
        pressedKeys.removeAll()
    }

    private mutating func expireSequence(at timestamp: TimeInterval, interval: TimeInterval) {
        switch state {
        case .firstPressed(let firstDown), .armed(let firstDown):
            if timestamp - firstDown > interval { reset() }
        default:
            break
        }
    }

    private func disallowedModifierMask(for shortcut: CaptureShortcut) -> UInt64 {
        let momentary = CGEventFlags.maskCommand.rawValue
            | CGEventFlags.maskAlternate.rawValue
            | CGEventFlags.maskControl.rawValue
            | CGEventFlags.maskSecondaryFn.rawValue
            | CGEventFlags.maskShift.rawValue
        return momentary & ~shortcut.cgEventFlag.rawValue
    }
}

extension CaptureShortcut {
    var keyCodes: Set<UInt16> {
        switch self {
        case .shift: [56, 60]
        case .option: [58, 61]
        case .control: [59, 62]
        case .command: [54, 55]
        }
    }

    var cgEventFlag: CGEventFlags {
        switch self {
        case .shift: .maskShift
        case .option: .maskAlternate
        case .control: .maskControl
        case .command: .maskCommand
        }
    }
}
