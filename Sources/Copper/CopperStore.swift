import AppKit
import Foundation

@MainActor
final class CopperStore: ObservableObject {
    @Published private(set) var document: CopperDocument
    @Published var activeSectionID: UUID

    let fileURL: URL

    init(fileURL customFileURL: URL? = nil) {
        let defaultDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Copper", isDirectory: true)
        let resolvedFileURL = customFileURL ?? defaultDirectory.appendingPathComponent("notes.json")
        let directory = resolvedFileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = resolvedFileURL

        let loadedDocument: CopperDocument
        if let data = try? Data(contentsOf: fileURL),
           let saved = try? JSONDecoder().decode(CopperDocument.self, from: data),
           !saved.sections.isEmpty {
            loadedDocument = saved
        } else {
            loadedDocument = .empty
        }
        document = loadedDocument
        activeSectionID = loadedDocument.sections[0].id
    }

    var sections: [CopperSection] { document.sections }
    var notes: [CopperNote] { document.notes }
    var captureShortcut: CaptureShortcut { document.captureShortcut }
    var captureInterval: Double { document.captureInterval }

    func addNote(_ rawText: String, sectionID: UUID? = nil) {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let destination = sectionID ?? activeSectionID
        document.notes.insert(CopperNote(text: text, sectionID: destination), at: 0)
        save()
    }

    func updateNote(id: UUID, text: String) {
        guard let index = document.notes.firstIndex(where: { $0.id == id }) else { return }
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        document.notes[index].text = cleaned
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
        let merged = CopperNote(
            text: selected.map(\.text).joined(separator: "\n\n"),
            sectionID: first.sectionID,
            createdAt: Date()
        )
        document.notes.insert(merged, at: 0)
        save()
        return merged.id
    }

    func addSection(named rawName: String) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let section = CopperSection(name: name)
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
        NotificationCenter.default.post(name: .copperShortcutChanged, object: nil)
    }

    func setCaptureInterval(_ interval: Double) {
        document.captureInterval = interval
        save()
        NotificationCenter.default.post(name: .copperShortcutChanged, object: nil)
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
    static let copperShortcutChanged = Notification.Name("CopperShortcutChanged")
    static let copperFocusComposer = Notification.Name("CopperFocusComposer")
}
