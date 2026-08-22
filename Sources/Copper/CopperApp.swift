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
            command(.copperNewLongform)
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
            slugCommand("revealNotesFile") {
                NSWorkspace.shared.activateFileViewerSelecting([AppDelegate.store.fileURL])
            }
            Divider()
            command(.copperShowShortcutGuide)
        }
    }

    @ViewBuilder
    private func command(_ notification: Notification.Name) -> some View {
        if let entry = ShortcutMap.entry(for: notification), let key = entry.keyEquivalent {
            Button(entry.title) { NotificationCenter.default.post(name: notification, object: nil) }
                .keyboardShortcut(key, modifiers: entry.modifiers)
        }
    }

    @ViewBuilder
    private func slugCommand(_ slug: String, action: @escaping () -> Void) -> some View {
        if let entry = ShortcutMap.entry(slug: slug), let key = entry.keyEquivalent {
            Button(entry.title, action: action)
                .keyboardShortcut(key, modifiers: entry.modifiers)
        }
    }
}
