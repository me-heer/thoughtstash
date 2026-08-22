import SwiftUI

@main
struct StashApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(AppDelegate.store)
        }
        .commands {
            StashCommands()
        }
    }
}

private struct StashCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            command(.stashFocusComposer)
            command(.stashNewNote)
            command(.stashNewSection)
        }

        CommandMenu("Notes") {
            command(.stashFocusSearch)
            Divider()
            command(.stashSelectPrevious)
            command(.stashSelectNext)
            command(.stashExtendSelectionPrevious)
            command(.stashExtendSelectionNext)
            Divider()
            command(.stashCopySelected)
            command(.stashCopySelectedAsList)
            command(.stashToggleDone)
            command(.stashEditSelected)
            command(.stashExpandSelected)
            command(.stashMergeSelected)
            command(.stashMoveToPreviousSection)
            command(.stashMoveToNextSection)
            Divider()
            command(.stashDeleteSelected)
            command(.stashDeleteActiveSection)
            Divider()
            command(.stashRevealNotesFile)
            Divider()
            command(.stashCycleFont)
            Divider()
            command(.stashShowShortcutGuide)
        }
    }

    // Deliberately has no `.keyboardShortcut`: the actual key handling is owned by
    // NotesKeyMonitor, which reads the same ShortcutMap entries. That avoids a race
    // between AppKit menu key-equivalents and a focused text field's own key bindings
    // (e.g. ⌘Delete/⌘↑/⌘↓ in a multi-line TextField). These buttons stay clickable
    // from the Notes menu for discoverability and mouse use.
    @ViewBuilder
    private func command(_ notification: Notification.Name) -> some View {
        if let entry = ShortcutMap.entry(for: notification) {
            Button(entry.title) { NotificationCenter.default.post(name: notification, object: nil) }
        }
    }
}
