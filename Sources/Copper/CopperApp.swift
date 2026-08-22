import SwiftUI

@main
struct CopperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(AppDelegate.store)
        }
        .commands {
            CopperCommands()
        }
    }
}

private struct CopperCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            command(.copperFocusComposer)
            command(.copperNewNote)
            command(.copperNewSection)
        }

        CommandMenu("Notes") {
            command(.copperFocusSearch)
            Divider()
            command(.copperSelectPrevious)
            command(.copperSelectNext)
            Divider()
            command(.copperCopySelected)
            command(.copperCopySelectedAsList)
            command(.copperToggleDone)
            command(.copperEditSelected)
            command(.copperExpandSelected)
            command(.copperMergeSelected)
            command(.copperMoveToNextSection)
            Divider()
            command(.copperDeleteSelected)
            command(.copperDeleteActiveSection)
            Divider()
            command(.copperRevealNotesFile)
            Divider()
            command(.copperShowShortcutGuide)
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
