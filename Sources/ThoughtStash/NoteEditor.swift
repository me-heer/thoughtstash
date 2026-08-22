import AppKit
import SwiftUI

struct NoteEditorContext: Identifiable {
    let id = UUID()
    let note: StashNote?
}

struct NoteEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appFontTheme) private var fontTheme
    let sections: [StashSection]
    let onSave: (_ markdown: String, _ sectionID: UUID) -> Void

    @State private var markdown: String
    @State private var sectionID: UUID
    @State private var isConfirmingDiscard = false
    @State private var focusRequest = UUID()
    @State private var keyMonitor: Any?
    private let originalMarkdown: String
    private let originalSectionID: UUID
    private let isNewNote: Bool

    init(
        note: StashNote?,
        sections: [StashSection],
        initialSectionID: UUID,
        onSave: @escaping (_ markdown: String, _ sectionID: UUID) -> Void
    ) {
        self.sections = sections
        self.onSave = onSave
        let initialMarkdown = note?.text ?? ""
        let initialSection = note?.sectionID ?? initialSectionID
        isNewNote = note == nil
        originalMarkdown = initialMarkdown
        originalSectionID = initialSection
        _markdown = State(initialValue: initialMarkdown)
        _sectionID = State(initialValue: initialSection)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            LiveMarkdownEditor(text: $markdown, focusRequest: focusRequest, fontTheme: fontTheme)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
            .padding(18)

            HStack {
                Label("The first line becomes the note title", systemImage: "textformat")
                Spacer()
                Text("\(markdown.count) characters")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .frame(width: 760, height: 560)
        .interactiveDismissDisabled(isDirty)
        .onAppear {
            installKeyMonitor()
            refocusEditor()
        }
        .onDisappear { removeKeyMonitor() }
        .confirmationDialog(
            "Discard changes?",
            isPresented: $isConfirmingDiscard,
            titleVisibility: .visible
        ) {
            Button("Discard Changes", role: .destructive) { dismiss() }
            Button("Keep Editing", role: .cancel) { refocusEditor() }
        } message: {
            Text("Your changes to this note have not been saved.")
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text(isNewNote ? "New Note" : "Edit Note")
                .font(.title2.weight(.semibold))

            Picker("Section", selection: $sectionID) {
                ForEach(sections) { section in Text(section.name).tag(section.id) }
            }
            .labelsHidden()
            .fixedSize()

            Spacer()

            Button("Cancel") { cancel() }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.glass)

            Button("Save") { save() }
                .buttonStyle(.glassProminent)
                .keyboardShortcut("s", modifiers: .command)
                .disabled(markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(16)
    }

    private var isDirty: Bool {
        markdown != originalMarkdown || sectionID != originalSectionID
    }

    private func cancel() {
        if isDirty { isConfirmingDiscard = true }
        else { dismiss() }
    }

    private func refocusEditor() {
        focusRequest = UUID()
    }

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard modifiers == .command,
                  event.charactersIgnoringModifiers?.lowercased() == "s" else {
                return event
            }
            guard !markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            save()
            return nil
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }

    private func save() {
        onSave(markdown, sectionID)
        dismiss()
    }
}
