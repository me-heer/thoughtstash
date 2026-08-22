import AppKit
import ApplicationServices
import SwiftUI

@MainActor
final class CaptureService {
    private let store: CopperStore
    private let showPanel: () -> Void
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var lastModifierTap: TimeInterval = 0
    private var toastWindow: NSPanel?

    init(store: CopperStore, showPanel: @escaping () -> Void) {
        self.store = store
        self.showPanel = showPanel
        installMonitors()
        NotificationCenter.default.addObserver(
            forName: .copperShortcutChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.lastModifierTap = 0 }
        }
    }

    deinit {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
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

    private func installMonitors() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor in self?.handle(event) }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor in self?.handle(event) }
            return event
        }
    }

    private func handle(_ event: NSEvent) {
        let expectedFlag: NSEvent.ModifierFlags
        let expectedCodes: Set<UInt16>
        switch store.captureShortcut {
        case .shift:
            expectedFlag = .shift
            expectedCodes = [56, 60]
        case .option:
            expectedFlag = .option
            expectedCodes = [58, 61]
        case .control:
            expectedFlag = .control
            expectedCodes = [59, 62]
        case .command:
            expectedFlag = .command
            expectedCodes = [54, 55]
        }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard expectedCodes.contains(event.keyCode), flags.contains(expectedFlag) else { return }

        let now = ProcessInfo.processInfo.systemUptime
        if now - lastModifierTap <= store.captureInterval {
            lastModifierTap = 0
            captureSelection()
        } else {
            lastModifierTap = now
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
