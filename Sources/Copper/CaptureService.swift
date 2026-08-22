import AppKit
import ApplicationServices
import SwiftUI

@MainActor
final class CaptureService {
    private let store: CopperStore
    private let showPanel: () -> Void
    private var localMonitor: Any?
    private var globalMonitor: GlobalShortcutMonitor?
    private var recognizer = DoubleModifierRecognizer()
    private var globalObservationAvailable = false
    private var toastWindow: NSPanel?
    private var observers: [NSObjectProtocol] = []

    init(store: CopperStore, showPanel: @escaping () -> Void) {
        self.store = store
        self.showPanel = showPanel
        installLocalMonitor()
        observers.append(NotificationCenter.default.addObserver(
            forName: .copperShortcutChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.recognizer.reset() }
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.ensureGlobalMonitor() }
        })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.restartGlobalMonitor() }
        })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.restartGlobalMonitor() }
        })
    }

    deinit {
        globalMonitor?.stop()
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.forEach(NSWorkspace.shared.notificationCenter.removeObserver)
    }

    func start() {
        requestAccessibility()
        ensureGlobalMonitor(requestPermission: true)
    }

    func requestAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    func captureSelection() {
        guard AXIsProcessTrusted() else {
            requestAccessibility()
            return
        }

        if let text = selectedText()?.trimmingCharacters(in: .whitespacesAndNewlines),
           !text.isEmpty {
            finishCapture(text)
            return
        }

        captureSelectionThroughClipboard()
    }

    private func installLocalMonitor() {
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown, .keyUp]) { [weak self] event in
            Task { @MainActor in
                guard let self, !self.globalObservationAvailable else { return }
                self.handle(KeyboardSample(
                    kind: event.type == .flagsChanged ? .flagsChanged : (event.type == .keyDown ? .keyDown : .keyUp),
                    keyCode: event.keyCode,
                    flags: CGEventFlags(rawValue: UInt64(event.modifierFlags.rawValue)),
                    timestamp: event.timestamp
                ))
            }
            return event
        }
    }

    private func handle(_ sample: KeyboardSample) {
        if recognizer.process(
            sample,
            shortcut: store.captureShortcut,
            interval: store.captureInterval
        ) {
            captureSelection()
        }
    }

    private func ensureGlobalMonitor(requestPermission: Bool = false) {
        guard CGPreflightListenEventAccess() else {
            globalObservationAvailable = false
            recognizer.reset()
            if requestPermission { CGRequestListenEventAccess() }
            return
        }
        guard globalMonitor == nil else { return }

        let monitor = GlobalShortcutMonitor(
            sampleHandler: { [weak self] sample in
                DispatchQueue.main.async { self?.handle(sample) }
            },
            availabilityHandler: { [weak self] available in
                DispatchQueue.main.async {
                    self?.globalObservationAvailable = available
                    self?.recognizer.reset()
                }
            }
        )
        globalMonitor = monitor
        monitor.start()
    }

    private func restartGlobalMonitor() {
        recognizer.reset()
        globalObservationAvailable = false
        globalMonitor?.stop()
        globalMonitor = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.ensureGlobalMonitor()
        }
    }

    private func selectedText() -> String? {
        let system = AXUIElementCreateSystemWide()
        var focusedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            system,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        ) == .success,
        let focusedValue else { return nil }

        let element = focusedValue as! AXUIElement
        var selectedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            &selectedValue
        ) == .success else { return nil }
        return selectedValue as? String
    }

    private func captureSelectionThroughClipboard() {
        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot(pasteboard: pasteboard)
        let marker = "copper-capture-\(UUID().uuidString)"
        pasteboard.clearContents()
        pasteboard.setString(marker, forType: .string)

        postCopyShortcut()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            let copiedText = pasteboard.string(forType: .string)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            snapshot.restore(to: pasteboard)

            guard let self else { return }
            if let copiedText, !copiedText.isEmpty, copiedText != marker {
                self.finishCapture(copiedText)
            } else {
                self.showPanel()
            }
        }
    }

    private func postCopyShortcut() {
        guard let source = CGEventSource(stateID: .combinedSessionState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: false) else { return }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cgSessionEventTap)
        keyUp.post(tap: .cgSessionEventTap)
    }

    private func finishCapture(_ text: String) {
        store.addNote(text)
        showToast()
    }

    private func showToast() {
        toastWindow?.close()
        let mouse = NSEvent.mouseLocation
        let panel = NSPanel(
            contentRect: NSRect(x: mouse.x + 14, y: mouse.y - 46, width: 106, height: 36),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.contentView = NSHostingView(rootView: CaptureToast())
        panel.orderFrontRegardless()
        toastWindow = panel

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { [weak self, weak panel] in
            panel?.animator().alphaValue = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                panel?.close()
                if self?.toastWindow === panel { self?.toastWindow = nil }
            }
        }
    }
}

private struct PasteboardSnapshot {
    private let items: [[NSPasteboard.PasteboardType: Data]]

    init(pasteboard: NSPasteboard) {
        items = (pasteboard.pasteboardItems ?? []).map { item in
            Dictionary(uniqueKeysWithValues: item.types.compactMap { type in
                item.data(forType: type).map { (type, $0) }
            })
        }
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        let restoredItems = items.map { values in
            let item = NSPasteboardItem()
            for (type, data) in values { item.setData(data, forType: type) }
            return item
        }
        if !restoredItems.isEmpty { pasteboard.writeObjects(restoredItems) }
    }
}
