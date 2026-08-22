import AppKit

/// Owns every Notes-menu shortcut deterministically via a local key-down monitor,
/// instead of relying on AppKit menu key-equivalents. Menu key-equivalents are supposed
/// to pre-empt the focused responder, but a multi-line text field (the composer) has its
/// own Cocoa bindings for some of the same combos (⌘Delete, ⌘↑/⌘↓), and in practice that
/// races/loses intermittently. This monitor is scoped to the main panel window only
/// (`event.window === targetWindow`), so any open sheet — the note editor, new-section
/// dialog, shortcut guide — gets its own window and is unaffected.
@MainActor
final class NotesKeyMonitor {
    private weak var targetWindow: NSWindow?
    private var monitor: Any?

    init(targetWindow: NSWindow?) {
        self.targetWindow = targetWindow
    }

    func start() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self,
                  event.window === self.targetWindow,
                  let entry = ShortcutMap.matchingEntry(for: event),
                  let notification = entry.notification else {
                return event
            }
            NotificationCenter.default.post(name: notification, object: nil)
            return nil
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    deinit {
        if let monitor { NSEvent.removeMonitor(monitor) }
    }
}
