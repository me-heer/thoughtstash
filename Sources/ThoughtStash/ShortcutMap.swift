import AppKit
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

/// Single source of truth for every Thought Stash shortcut: the Notes menu, the in-app
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
            notification: .stashFocusComposer,
            group: .notes
        ),
        ShortcutEntry(
            slug: "composerNewline",
            "New Line in Quick Composer",
            key: .return, modifiers: [.shift],
            group: .notes
        ),
        ShortcutEntry(
            slug: "newNote",
            "New Note…",
            key: "n", modifiers: [.command, .shift],
            notification: .stashNewNote,
            group: .notes
        ),
        ShortcutEntry(
            slug: "newSection",
            "New Section…",
            key: "n", modifiers: [.command, .option],
            notification: .stashNewSection,
            group: .sections
        ),
        ShortcutEntry(
            slug: "focusSearch",
            "Search",
            key: "f", modifiers: [.command],
            notification: .stashFocusSearch,
            group: .notes
        ),
        ShortcutEntry(
            slug: "selectPrevious",
            "Select Previous Note",
            key: .upArrow, modifiers: [.command],
            notification: .stashSelectPrevious,
            group: .selection
        ),
        ShortcutEntry(
            slug: "selectNext",
            "Select Next Note",
            key: .downArrow, modifiers: [.command],
            notification: .stashSelectNext,
            group: .selection
        ),
        ShortcutEntry(
            slug: "vimSelectPrevious",
            "Select Previous Note (Vim)",
            key: "k", modifiers: [.command],
            notification: .stashSelectPrevious,
            group: .selection
        ),
        ShortcutEntry(
            slug: "vimSelectNext",
            "Select Next Note (Vim)",
            key: "j", modifiers: [.command],
            notification: .stashSelectNext,
            group: .selection
        ),
        ShortcutEntry(
            slug: "copySelected",
            "Copy Selected Notes",
            key: "c", modifiers: [.command, .option],
            notification: .stashCopySelected,
            group: .selection
        ),
        ShortcutEntry(
            slug: "copySelectedAsList",
            "Copy Selected as List",
            key: "c", modifiers: [.command, .shift],
            notification: .stashCopySelectedAsList,
            group: .selection
        ),
        ShortcutEntry(
            slug: "toggleDone",
            "Mark Selected Done",
            key: "d", modifiers: [.command],
            notification: .stashToggleDone,
            group: .selection
        ),
        ShortcutEntry(
            slug: "editSelected",
            "Edit Selected Note",
            key: "e", modifiers: [.command],
            notification: .stashEditSelected,
            group: .editing
        ),
        ShortcutEntry(
            slug: "expandSelected",
            "Expand Selected Note",
            key: .return, modifiers: [.command, .option],
            notification: .stashExpandSelected,
            group: .editing
        ),
        ShortcutEntry(
            slug: "mergeSelected",
            "Merge Selected Notes",
            key: "m", modifiers: [.command, .shift],
            notification: .stashMergeSelected,
            group: .editing
        ),
        ShortcutEntry(
            slug: "moveToNextSection",
            "Move to Next Section",
            key: .rightArrow, modifiers: [.command, .option],
            notification: .stashMoveToNextSection,
            group: .sections
        ),
        ShortcutEntry(
            slug: "deleteSelected",
            "Delete Selected Notes",
            key: .delete, modifiers: [.command],
            notification: .stashDeleteSelected,
            group: .selection
        ),
        ShortcutEntry(
            slug: "deleteActiveSection",
            "Delete Active Section",
            key: .delete, modifiers: [.command, .option],
            notification: .stashDeleteActiveSection,
            group: .sections
        ),
        ShortcutEntry(
            slug: "revealNotesFile",
            "Reveal Notes File",
            key: "r", modifiers: [.command, .shift],
            notification: .stashRevealNotesFile,
            group: .app
        ),
        ShortcutEntry(
            slug: "shortcutGuide",
            "Keyboard Shortcuts…",
            key: "/", modifiers: [.command],
            notification: .stashShowShortcutGuide,
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
            "Save a note",
            group: .editing,
            displayOverride: "⌘S"
        ),
        ShortcutEntry(
            slug: "cancelDialog",
            "Close Thought Stash / cancel a dialog",
            group: .app,
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

    /// Matches a raw key-down event against the notification-backed entries, so a local
    /// `NSEvent` monitor can dispatch shortcuts deterministically instead of relying on
    /// AppKit menu key-equivalents (which can lose a race with a focused text field).
    static func matchingEntry(for event: NSEvent) -> ShortcutEntry? {
        matchingEntry(
            keyCode: event.keyCode,
            charactersIgnoringModifiers: event.charactersIgnoringModifiers,
            modifierFlags: event.modifierFlags
        )
    }

    static func matchingEntry(
        keyCode: UInt16,
        charactersIgnoringModifiers: String?,
        modifierFlags: NSEvent.ModifierFlags
    ) -> ShortcutEntry? {
        let modifiers = eventModifiers(from: modifierFlags)
        return all.first { entry in
            guard entry.notification != nil, let key = entry.keyEquivalent else { return false }
            return entry.modifiers == modifiers
                && keyMatches(key, keyCode: keyCode, charactersIgnoringModifiers: charactersIgnoringModifiers)
        }
    }

    private static func keyMatches(
        _ key: KeyEquivalent,
        keyCode: UInt16,
        charactersIgnoringModifiers: String?
    ) -> Bool {
        // Delete keys are not guaranteed to provide charactersIgnoringModifiers. Match
        // their hardware-independent virtual key codes before using character matching.
        if key == .delete { return keyCode == 51 || keyCode == 117 }
        guard let char = charactersIgnoringModifiers?.lowercased().first else { return false }
        return String(key.character).lowercased().first == char
    }

    private static func eventModifiers(from flags: NSEvent.ModifierFlags) -> EventModifiers {
        var modifiers: EventModifiers = []
        if flags.contains(.command) { modifiers.insert(.command) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.control) { modifiers.insert(.control) }
        return modifiers
    }
}
