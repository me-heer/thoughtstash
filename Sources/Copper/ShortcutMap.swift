import SwiftUI

enum ShortcutGroup: String, CaseIterable, Identifiable {
    case capture = "Capture"
    case notes = "Notes"
    case selection = "Selection"
    case editing = "Editing"
    case sections = "Sections"
    case app = "App"

    var id: String { rawValue }
}

/// A single row in the keyboard map. `notification`/`slug` let call sites look an entry
/// up either by the NotificationCenter event it posts (menu commands, ambient hints) or
/// by a stable name (actions with no notification, e.g. Reveal Notes File).
struct ShortcutEntry: Identifiable {
    let id = UUID()
    let slug: String
    let title: String
    let keyEquivalent: KeyEquivalent?
    let modifiers: EventModifiers
    let notification: Notification.Name?
    let group: ShortcutGroup
    let displayString: String

    init(
        slug: String,
        _ title: String,
        key: KeyEquivalent? = nil,
        modifiers: EventModifiers = [],
        notification: Notification.Name? = nil,
        group: ShortcutGroup,
        displayOverride: String? = nil
    ) {
        self.slug = slug
        self.title = title
        self.keyEquivalent = key
        self.modifiers = modifiers
        self.notification = notification
        self.group = group
        self.displayString = displayOverride ?? Self.glyphs(for: modifiers, key: key)
    }

    private static func glyphs(for modifiers: EventModifiers, key: KeyEquivalent?) -> String {
        var result = ""
        if modifiers.contains(.control) { result += "⌃" }
        if modifiers.contains(.option) { result += "⌥" }
        if modifiers.contains(.shift) { result += "⇧" }
        if modifiers.contains(.command) { result += "⌘" }
        guard let key else { return result }
        result += glyph(for: key)
        return result
    }

    private static func glyph(for key: KeyEquivalent) -> String {
        switch key {
        case .upArrow: return "↑"
        case .downArrow: return "↓"
        case .leftArrow: return "←"
        case .rightArrow: return "→"
        case .delete: return "⌫"
        case .escape: return "⎋"
        case .return: return "⏎"
        case .space: return "Space"
        case .tab: return "⇥"
        default: return String(key.character).uppercased()
        }
    }
}

/// Single source of truth for every Copper shortcut: the Notes menu, the in-app
/// shortcut guide, and ambient hints all read from this array so they can't drift apart.
enum ShortcutMap {
    static let all: [ShortcutEntry] = [
        ShortcutEntry(
            slug: "captureSelection",
            "Capture selection / show and focus composer",
            group: .capture,
            displayOverride: "Shift, Shift"
        ),
        ShortcutEntry(
            slug: "focusComposer",
            "New Quick Note",
            key: "n", modifiers: [.command],
            notification: .copperFocusComposer,
            group: .notes
        ),
        ShortcutEntry(
            slug: "newLongform",
            "New Longform Note…",
            key: "n", modifiers: [.command, .shift],
            notification: .copperNewLongform,
            group: .notes
        ),
        ShortcutEntry(
            slug: "newSection",
            "New Section…",
            key: "n", modifiers: [.command, .option],
            notification: .copperNewSection,
            group: .sections
        ),
        ShortcutEntry(
            slug: "focusSearch",
            "Search",
            key: "f", modifiers: [.command],
            notification: .copperFocusSearch,
            group: .notes
        ),
        ShortcutEntry(
            slug: "selectPrevious",
            "Select Previous Note",
            key: .upArrow, modifiers: [.command],
            notification: .copperSelectPrevious,
            group: .selection
        ),
        ShortcutEntry(
            slug: "selectNext",
            "Select Next Note",
            key: .downArrow, modifiers: [.command],
            notification: .copperSelectNext,
            group: .selection
        ),
        ShortcutEntry(
            slug: "copySelected",
            "Copy Selected Notes",
            key: "c", modifiers: [.command, .option],
            notification: .copperCopySelected,
            group: .selection
        ),
        ShortcutEntry(
            slug: "copySelectedAsList",
            "Copy Selected as List",
            key: "c", modifiers: [.command, .shift],
            notification: .copperCopySelectedAsList,
            group: .selection
        ),
        ShortcutEntry(
            slug: "toggleDone",
            "Mark Selected Done",
            key: "d", modifiers: [.command],
            notification: .copperToggleDone,
            group: .selection
        ),
        ShortcutEntry(
            slug: "editSelected",
            "Edit Selected Note",
            key: "e", modifiers: [.command],
            notification: .copperEditSelected,
            group: .editing
        ),
        ShortcutEntry(
            slug: "expandSelected",
            "Expand Selected Note",
            key: .return, modifiers: [.command, .option],
            notification: .copperExpandSelected,
            group: .editing
        ),
        ShortcutEntry(
            slug: "mergeSelected",
            "Merge Selected Notes",
            key: "m", modifiers: [.command, .shift],
            notification: .copperMergeSelected,
            group: .editing
        ),
        ShortcutEntry(
            slug: "moveToNextSection",
            "Move to Next Section",
            key: .rightArrow, modifiers: [.command, .option],
            notification: .copperMoveToNextSection,
            group: .sections
        ),
        ShortcutEntry(
            slug: "deleteSelected",
            "Delete Selected Notes",
            key: .delete, modifiers: [.command],
            notification: .copperDeleteSelected,
            group: .selection
        ),
        ShortcutEntry(
            slug: "deleteActiveSection",
            "Delete Active Section",
            key: .delete, modifiers: [.command, .option],
            notification: .copperDeleteActiveSection,
            group: .sections
        ),
        ShortcutEntry(
            slug: "revealNotesFile",
            "Reveal Notes File",
            key: "r", modifiers: [.command, .shift],
            group: .app
        ),
        ShortcutEntry(
            slug: "shortcutGuide",
            "Keyboard Shortcuts…",
            key: "/", modifiers: [.command],
            notification: .copperShowShortcutGuide,
            group: .app
        ),
        ShortcutEntry(
            slug: "settings",
            "Settings…",
            key: ",", modifiers: [.command],
            group: .app
        ),
        ShortcutEntry(
            slug: "saveEditor",
            "Save an editor",
            group: .editing,
            displayOverride: "⌘S or Return"
        ),
        ShortcutEntry(
            slug: "cancelDialog",
            "Cancel a dialog or editor",
            group: .editing,
            displayOverride: "Escape"
        ),
    ]

    static func entry(for notification: Notification.Name) -> ShortcutEntry? {
        all.first { $0.notification == notification }
    }

    static func entry(slug: String) -> ShortcutEntry? {
        all.first { $0.slug == slug }
    }

    static func display(for notification: Notification.Name) -> String? {
        entry(for: notification)?.displayString
    }
}
