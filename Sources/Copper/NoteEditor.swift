import SwiftUI

struct NoteEditorContext: Identifiable {
    let id = UUID()
    let note: CopperNote?
    let startExpanded: Bool
}

/// A single editor for every note. There is no separate "longform" editor: any note can
/// carry a title (shown here whether compact or expanded) and any note's editor can be
/// expanded to a larger window via the header button or ⇧⌘Return. Whether the saved note
/// displays as "longform" in the list is inferred from whether a title was given.
struct NoteEditor: View {
    @Environment(\.dismiss) private var dismiss
    let sections: [CopperSection]
    let onSave: (_ title: String, _ markdown: String, _ sectionID: UUID) -> Void

    @State private var title: String
    @State private var markdown: String
    @State private var sectionID: UUID
    @State private var isExpanded: Bool
    @FocusState private var isTitleFocused: Bool
    @FocusState private var isBodyFocused: Bool

    init(
        note: CopperNote?,
        sections: [CopperSection],
        initialSectionID: UUID,
        startExpanded: Bool,
        onSave: @escaping (_ title: String, _ markdown: String, _ sectionID: UUID) -> Void
    ) {
        self.sections = sections
        self.onSave = onSave
        _title = State(initialValue: note?.title ?? "")
        _markdown = State(initialValue: note?.text ?? "")
        _sectionID = State(initialValue: note?.sectionID ?? initialSectionID)
        _isExpanded = State(initialValue: startExpanded || note?.isLongform == true)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            InlineMarkdownEditor(text: $markdown, isFocused: $isBodyFocused, compact: !isExpanded)
                .padding(16)
        }
        .frame(
            width: isExpanded ? 880 : 480,
            height: isExpanded ? 600 : 360
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: isExpanded)
        .onAppear {
            DispatchQueue.main.async {
                if isExpanded && title.isEmpty {
                    isTitleFocused = true
                } else {
                    isBodyFocused = true
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            TextField(isExpanded ? "Untitled note" : "Title (optional)", text: $title)
                .textFieldStyle(.plain)
                .font(isExpanded ? .title2.weight(.semibold) : .body.weight(.medium))
                .focused($isTitleFocused)

            Picker("Section", selection: $sectionID) {
                ForEach(sections) { section in Text(section.name).tag(section.id) }
            }
            .labelsHidden()
            .fixedSize()

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                    isExpanded.toggle()
                }
            } label: {
                Image(systemName: isExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
            }
            .buttonStyle(.glass)
            .keyboardShortcut(.return, modifiers: [.command, .shift])

            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.glass)

            Button("Save") { save() }
                .buttonStyle(.glassProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(16)
    }

    private func save() {
        onSave(title.trimmingCharacters(in: .whitespacesAndNewlines), markdown, sectionID)
        dismiss()
    }
}
