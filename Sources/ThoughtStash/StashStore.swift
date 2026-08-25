import AppKit
import Foundation

@MainActor
final class StashStore: ObservableObject {
    @Published private(set) var document: StashDocument
    @Published var activeSectionID: UUID

    let fileURL: URL

    init(fileURL customFileURL: URL? = nil) {
        let defaultDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Thought Stash", isDirectory: true)
        let resolvedFileURL = customFileURL ?? defaultDirectory.appendingPathComponent("notes.json")
        let directory = resolvedFileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = resolvedFileURL

        let loadedDocument: StashDocument
        if let data = try? Data(contentsOf: fileURL),
           let saved = try? JSONDecoder().decode(StashDocument.self, from: data),
           !saved.sections.isEmpty {
            loadedDocument = saved
        } else {
            loadedDocument = .empty
        }
        document = loadedDocument
        activeSectionID = loadedDocument.sections[0].id
    }

    var sections: [StashSection] { document.sections }
    var inboxSection: StashSection? { document.sections.first }
    var notes: [StashNote] { document.notes }
    var captureShortcut: CaptureShortcut { document.captureShortcut }
    var captureInterval: Double { document.captureInterval }
    var fontTheme: AppFontTheme { document.fontTheme }
    var showsMenuBarItem: Bool { document.showsMenuBarItem }

    func addNote(
        _ rawText: String,
        sectionID: UUID? = nil,
        richTextRTF: Data? = nil
    ) {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let destination = sectionID ?? activeSectionID
        document.notes.insert(StashNote(
            text: text,
            sectionID: destination,
            richTextRTF: richTextRTF
        ), at: 0)
        save()
    }

    func updateNote(
        id: UUID,
        text: String,
        sectionID: UUID? = nil
    ) {
        guard let index = document.notes.firstIndex(where: { $0.id == id }) else { return }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        document.notes[index].text = text
        document.notes[index].richTextRTF = nil
        if let sectionID { document.notes[index].sectionID = sectionID }
        save()
    }

    func toggleDone(_ ids: Set<UUID>) {
        let shouldComplete = document.notes.filter { ids.contains($0.id) }.contains { !$0.isDone }
        for index in document.notes.indices where ids.contains(document.notes[index].id) {
            document.notes[index].isDone = shouldComplete
        }
        save()
    }

    func move(_ ids: Set<UUID>, to sectionID: UUID) {
        for index in document.notes.indices where ids.contains(document.notes[index].id) {
            document.notes[index].sectionID = sectionID
        }
        save()
    }

    func delete(_ ids: Set<UUID>) {
        document.notes.removeAll { ids.contains($0.id) }
        save()
    }

    @discardableResult
    func merge(_ ids: Set<UUID>) -> UUID? {
        let selected = document.notes.filter { ids.contains($0.id) }
            .sorted { $0.createdAt < $1.createdAt }
        guard selected.count > 1, let first = selected.first else { return nil }
        document.notes.removeAll { ids.contains($0.id) }
        let mergedRTF = RichTextCodec.mergedRTF(notes: selected, asList: false)
        let merged = StashNote(
            text: selected.map(\.text).joined(separator: "\n\n"),
            sectionID: first.sectionID,
            createdAt: Date(),
            richTextRTF: mergedRTF
        )
        document.notes.insert(merged, at: 0)
        save()
        return merged.id
    }

    func addSection(named rawName: String) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let section = StashSection(name: name)
        document.sections.append(section)
        activeSectionID = section.id
        save()
    }

    func deleteSection(_ id: UUID) {
        guard document.sections.count > 1,
              let fallback = document.sections.first(where: { $0.id != id }) else { return }
        move(Set(document.notes.filter { $0.sectionID == id }.map(\.id)), to: fallback.id)
        document.sections.removeAll { $0.id == id }
        if activeSectionID == id { activeSectionID = fallback.id }
        save()
    }

    func setCaptureShortcut(_ shortcut: CaptureShortcut) {
        document.captureShortcut = shortcut
        save()
        NotificationCenter.default.post(name: .stashShortcutChanged, object: nil)
    }

    func setFontTheme(_ theme: AppFontTheme) {
        guard theme != document.fontTheme else { return }
        document.fontTheme = theme
        save()
    }

    @discardableResult
    func cycleFontTheme() -> AppFontTheme {
        let next = document.fontTheme.next
        setFontTheme(next)
        return next
    }

    func setCaptureInterval(_ interval: Double) {
        document.captureInterval = interval
        save()
        NotificationCenter.default.post(name: .stashShortcutChanged, object: nil)
    }

    func setShowsMenuBarItem(_ isVisible: Bool) {
        guard isVisible != document.showsMenuBarItem else { return }
        document.showsMenuBarItem = isVisible
        save()
        NotificationCenter.default.post(name: .stashMenuBarVisibilityChanged, object: nil)
    }

    func copy(_ ids: Set<UUID>, asList: Bool) {
        let selected = document.notes.filter { ids.contains($0.id) }
            .sorted { $0.createdAt < $1.createdAt }
        guard !selected.isEmpty else { return }
        let value: String
        if asList {
            value = selected.enumerated().map { index, note in
                "\(index + 1). \(note.text.replacingOccurrences(of: "\n", with: "\n   "))"
            }.joined(separator: "\n")
        } else {
            value = selected.map(\.text).joined(separator: "\n\n")
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        if let rtf = RichTextCodec.mergedRTF(notes: selected, asList: asList) {
            NSPasteboard.general.setData(rtf, forType: .rtf)
        }
    }

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(document)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            NSSound.beep()
        }
    }
}

extension Notification.Name {
    static let stashShortcutChanged = Notification.Name("StashShortcutChanged")
    static let stashMenuBarVisibilityChanged = Notification.Name("StashMenuBarVisibilityChanged")
    static let stashFocusComposer = Notification.Name("StashFocusComposer")
    static let stashNewNote = Notification.Name("StashNewNote")
    static let stashNewSection = Notification.Name("StashNewSection")
    static let stashFocusSearch = Notification.Name("StashFocusSearch")
    /// Escape inside the panel. Routed through the view rather than handled in the key
    /// monitor because what Escape means depends on view state: it collapses the search
    /// field back to the title row if search is open, and otherwise closes the panel.
    static let stashEscape = Notification.Name("StashEscape")
    static let stashSelectNext = Notification.Name("StashSelectNext")
    static let stashSelectPrevious = Notification.Name("StashSelectPrevious")
    static let stashExtendSelectionNext = Notification.Name("StashExtendSelectionNext")
    static let stashExtendSelectionPrevious = Notification.Name("StashExtendSelectionPrevious")
    static let stashCopySelected = Notification.Name("StashCopySelected")
    static let stashCopySelectedAsList = Notification.Name("StashCopySelectedAsList")
    static let stashToggleDone = Notification.Name("StashToggleDone")
    static let stashEditSelected = Notification.Name("StashEditSelected")
    static let stashExpandSelected = Notification.Name("StashExpandSelected")
    static let stashMergeSelected = Notification.Name("StashMergeSelected")
    static let stashMoveToNextSection = Notification.Name("StashMoveToNextSection")
    static let stashMoveToPreviousSection = Notification.Name("StashMoveToPreviousSection")
    static let stashDeleteSelected = Notification.Name("StashDeleteSelected")
    static let stashDeleteActiveSection = Notification.Name("StashDeleteActiveSection")
    static let stashShowShortcutGuide = Notification.Name("StashShowShortcutGuide")
    static let stashRevealNotesFile = Notification.Name("StashRevealNotesFile")
    static let stashCycleFont = Notification.Name("StashCycleFont")
}
