import SwiftUI

struct LongformEditor: View {
    @Environment(\.dismiss) private var dismiss

    let note: CopperNote?
    let sections: [CopperSection]
    let initialSectionID: UUID
    let onSave: (_ title: String, _ markdown: String, _ sectionID: UUID) -> Void

    @State private var title: String
    @State private var markdown: String
    @State private var sectionID: UUID
    @FocusState private var focusedField: Field?

    private enum Field { case title, body }

    init(
        note: CopperNote? = nil,
        sections: [CopperSection],
        initialSectionID: UUID,
        onSave: @escaping (_ title: String, _ markdown: String, _ sectionID: UUID) -> Void
    ) {
        self.note = note
        self.sections = sections
        self.initialSectionID = initialSectionID
        self.onSave = onSave
        _title = State(initialValue: note?.title ?? "")
        _markdown = State(initialValue: note?.text ?? "")
        _sectionID = State(initialValue: note?.sectionID ?? initialSectionID)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                TextField("Untitled note", text: $title)
                    .textFieldStyle(.plain)
                    .font(.title2.weight(.semibold))
                    .focused($focusedField, equals: .title)
                Picker("Section", selection: $sectionID) {
                    ForEach(sections) { section in Text(section.name).tag(section.id) }
                }
                .labelsHidden()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .buttonStyle(.glass)
                Button("Save") { save() }
                    .buttonStyle(.glassProminent)
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(16)

            Divider()

            HSplitView {
                VStack(alignment: .leading, spacing: 8) {
                    Text("MARKDOWN")
                        .font(.caption.weight(.semibold))
                        .tracking(1)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $markdown)
                        .font(.system(.body, design: .monospaced))
                        .focused($focusedField, equals: .body)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 10))
                }
                .padding(16)
                .frame(minWidth: 330)

                VStack(alignment: .leading, spacing: 8) {
                    Text("PREVIEW")
                        .font(.caption.weight(.semibold))
                        .tracking(1)
                        .foregroundStyle(.secondary)
                    ScrollView {
                        MarkdownPreview(markdown: markdown)
                            .textSelection(.enabled)
                            .padding(12)
                    }
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 10))
                }
                .padding(16)
                .frame(minWidth: 330)
            }
        }
        .frame(width: 880, height: 600)
        .onAppear {
            DispatchQueue.main.async { focusedField = title.isEmpty ? .title : .body }
        }
    }

    private func save() {
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        onSave(cleanedTitle.isEmpty ? "Untitled" : cleanedTitle, markdown, sectionID)
        dismiss()
    }
}
