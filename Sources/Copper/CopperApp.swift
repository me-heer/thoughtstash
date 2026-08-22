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
            command("New Quick Note", notification: .copperFocusComposer, key: "n")
            command("New Longform Note…", notification: .copperNewLongform, key: "n", modifiers: [.command, .shift])
            command("New Section…", notification: .copperNewSection, key: "n", modifiers: [.command, .option])
        }

        CommandMenu("Notes") {
            command("Find", notification: .copperFocusSearch, key: "f")
            Divider()
            command("Select Previous Note", notification: .copperSelectPrevious, key: .upArrow)
            command("Select Next Note", notification: .copperSelectNext, key: .downArrow)
            Divider()
            command("Copy Selected Notes", notification: .copperCopySelected, key: "c", modifiers: [.command, .option])
            command("Copy Selected as List", notification: .copperCopySelectedAsList, key: "c", modifiers: [.command, .shift])
            command("Mark Selected Done", notification: .copperToggleDone, key: "d")
            command("Edit Selected Note", notification: .copperEditSelected, key: "e")
            command("Expand Selected Note", notification: .copperExpandSelected, key: .return, modifiers: [.command, .option])
            command("Merge Selected Notes", notification: .copperMergeSelected, key: "m", modifiers: [.command, .shift])
            command("Move to Next Section", notification: .copperMoveToNextSection, key: .rightArrow, modifiers: [.command, .option])
            Divider()
            command("Delete Selected Notes", notification: .copperDeleteSelected, key: .delete, modifiers: [.command])
            command("Delete Active Section", notification: .copperDeleteActiveSection, key: .delete, modifiers: [.command, .option])
            Divider()
            Button("Reveal Notes File") {
                NSWorkspace.shared.activateFileViewerSelecting([AppDelegate.store.fileURL])
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
        }
    }

    private func command(
        _ title: String,
        notification: Notification.Name,
        key: KeyEquivalent,
        modifiers: EventModifiers = .command
    ) -> some View {
        Button(title) { NotificationCenter.default.post(name: notification, object: nil) }
            .keyboardShortcut(key, modifiers: modifiers)
    }
}
