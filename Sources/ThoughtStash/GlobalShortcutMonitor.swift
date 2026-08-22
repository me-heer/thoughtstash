import CoreGraphics
import Foundation

final class GlobalShortcutMonitor: @unchecked Sendable {
    typealias SampleHandler = (KeyboardSample) -> Void
    typealias AvailabilityHandler = (Bool) -> Void

    private let sampleHandler: SampleHandler
    private let availabilityHandler: AvailabilityHandler
    private let lock = NSLock()
    private var thread: Thread?
    private var runLoop: CFRunLoop?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var available = false

    init(
        sampleHandler: @escaping SampleHandler,
        availabilityHandler: @escaping AvailabilityHandler
    ) {
        self.sampleHandler = sampleHandler
        self.availabilityHandler = availabilityHandler
    }

    var isAvailable: Bool {
        lock.withLock { available }
    }

    func start() {
        lock.lock()
        guard thread == nil else {
            lock.unlock()
            return
        }
        let monitorThread = Thread { [weak self] in self?.run() }
        monitorThread.name = "Thought Stash global shortcut monitor"
        thread = monitorThread
        lock.unlock()
        monitorThread.start()
    }

    func stop() {
        lock.withLock { runLoop }.map(CFRunLoopStop)
    }

    private func run() {
        let mask = (CGEventMask(1) << CGEventType.flagsChanged.rawValue)
            | (CGEventMask(1) << CGEventType.keyDown.rawValue)
            | (CGEventMask(1) << CGEventType.keyUp.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: globalShortcutEventCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            setAvailable(false)
            lock.withLock { thread = nil }
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        lock.withLock {
            eventTap = tap
            runLoopSource = source
            runLoop = CFRunLoopGetCurrent()
        }
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        setAvailable(CGEvent.tapIsEnabled(tap: tap))
        CFRunLoopRun()

        setAvailable(false)
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        lock.withLock {
            eventTap = nil
            runLoopSource = nil
            runLoop = nil
            thread = nil
        }
    }

    fileprivate func receive(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            setAvailable(false)
            guard let tap = lock.withLock({ eventTap }) else { return }
            CGEvent.tapEnable(tap: tap, enable: true)
            setAvailable(CGEvent.tapIsEnabled(tap: tap))
            return
        }

        let kind: KeyboardSample.Kind
        switch type {
        case .flagsChanged: kind = .flagsChanged
        case .keyDown: kind = .keyDown
        case .keyUp: kind = .keyUp
        default: return
        }
        sampleHandler(KeyboardSample(
            kind: kind,
            keyCode: UInt16(event.getIntegerValueField(.keyboardEventKeycode)),
            flags: event.flags,
            timestamp: TimeInterval(event.timestamp) / 1_000_000_000
        ))
    }

    private func setAvailable(_ newValue: Bool) {
        let changed = lock.withLock { () -> Bool in
            guard available != newValue else { return false }
            available = newValue
            return true
        }
        if changed { availabilityHandler(newValue) }
    }
}

private let globalShortcutEventCallback: CGEventTapCallBack = { _, type, event, userInfo in
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let monitor = Unmanaged<GlobalShortcutMonitor>.fromOpaque(userInfo).takeUnretainedValue()
    monitor.receive(type: type, event: event)
    return Unmanaged.passUnretained(event)
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
