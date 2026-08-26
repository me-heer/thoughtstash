import AppKit
import SwiftUI

struct NoteEditorContext: Identifiable {
    let id = UUID()
    let note: StashNote?
    /// Text carried in from the quick composer, so ⇧⌘F mid-sentence doesn't drop it.
    var seedText: String?
    var startsInFocusMode = false
}

struct NoteEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appFontTheme) private var fontTheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let sections: [StashSection]
    let onSave: (_ markdown: String, _ sectionID: UUID) -> Void

    @State private var markdown: String
    @State private var sectionID: UUID
    @State private var isConfirmingDiscard = false
    @State private var focusRequest = UUID()
    @State private var keyMonitor: Any?
    @State private var isFocusMode: Bool
    @State private var isCommandHeld = false
    private let originalMarkdown: String
    private let originalSectionID: UUID
    private let isNewNote: Bool

    init(
        note: StashNote?,
        sections: [StashSection],
        initialSectionID: UUID,
        seedText: String? = nil,
        startsInFocusMode: Bool = false,
        onSave: @escaping (_ markdown: String, _ sectionID: UUID) -> Void
    ) {
        self.sections = sections
        self.onSave = onSave
        let initialMarkdown = note?.text ?? seedText ?? ""
        let initialSection = note?.sectionID ?? initialSectionID
        isNewNote = note == nil
        originalMarkdown = initialMarkdown
        originalSectionID = initialSection
        _markdown = State(initialValue: initialMarkdown)
        _sectionID = State(initialValue: initialSection)
        _isFocusMode = State(initialValue: startsInFocusMode)
    }

    var body: some View {
        Group {
            if isFocusMode {
                FocusEditorSurface(
                    markdown: $markdown,
                    sectionID: $sectionID,
                    sections: sections,
                    focusRequest: focusRequest,
                    isCommandHeld: isCommandHeld,
                    onExit: { toggleFocusMode() },
                    onSave: save
                )
            } else {
                standardEditor
            }
        }
        .frame(
            width: isFocusMode ? 900 : 760,
            height: isFocusMode ? 640 : 560
        )
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

    private var standardEditor: some View {
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

            Button { toggleFocusMode() } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
            }
            .buttonStyle(.glass)
            .help("Focus mode (\(ShortcutMap.display(for: .stashFocusMode) ?? "⇧⌘F"))")

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

    private var isEmpty: Bool {
        markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func cancel() {
        if isDirty { isConfirmingDiscard = true }
        else { dismiss() }
    }

    private func toggleFocusMode() {
        withAnimation(reduceMotion ? .none : .snappy(duration: 0.24)) {
            isFocusMode.toggle()
        }
        // A modifier released while the sheet was resizing never reports back.
        isCommandHeld = false
        refocusEditor()
    }

    private func refocusEditor() {
        focusRequest = UUID()
    }

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            if event.type == .flagsChanged {
                // Holding ⌘ is the keyboard-only way to bring the focus-mode bar back.
                if isFocusMode { isCommandHeld = event.modifierFlags.contains(.command) }
                return event
            }

            // The discard dialog owns its own keys while it is up.
            guard !isConfirmingDiscard else { return event }

            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if modifiers == .command, event.charactersIgnoringModifiers?.lowercased() == "s" {
                guard !isEmpty else { return nil }
                save()
                return nil
            }

            if ShortcutMap.matchingEntry(for: event)?.notification == .stashFocusMode {
                toggleFocusMode()
                return nil
            }

            // In focus mode Escape steps back to the ordinary editor rather than throwing
            // the note away — leaving the sheet is still Cancel's job.
            if event.keyCode == 53, isFocusMode {
                toggleFocusMode()
                return nil
            }

            return event
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }

    private func save() {
        guard !isEmpty else { return }
        onSave(markdown, sectionID)
        dismiss()
    }
}
