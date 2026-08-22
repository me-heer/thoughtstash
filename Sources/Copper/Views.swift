import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: CopperStore
    @State private var searchText = ""
    @State private var draft = ""
    @State private var selectedIDs = Set<UUID>()
    @State private var editingNote: CopperNote?
    @State private var expandedNote: CopperNote?
    @State private var isAddingSection = false
    @FocusState private var isComposerFocused: Bool

    private var filteredNotes: [CopperNote] {
        guard !searchText.isEmpty else { return store.notes }
        return store.notes.filter { $0.text.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        ZStack {
            VisualEffectView()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                noteList
                composer
            }
        }
        .frame(minWidth: 360, minHeight: 480)
        .sheet(item: $editingNote) { note in
            NoteEditor(note: note, title: "Edit Note") { text in
                store.updateNote(id: note.id, text: text)
            }
        }
        .sheet(item: $expandedNote) { note in
            ExpandedNote(note: note)
        }
        .sheet(isPresented: $isAddingSection) {
            NewSectionView { store.addSection(named: $0) }
        }
        .onAppear {
            DispatchQueue.main.async { isComposerFocused = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: .copperFocusComposer)) { _ in
            DispatchQueue.main.async { isComposerFocused = true }
        }
        .animation(.snappy(duration: 0.2), value: selectedIDs)
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search", text: $searchText)
                .textFieldStyle(.plain)
            Menu {
                Button("New Section…", systemImage: "folder.badge.plus") {
                    isAddingSection = true
                }
                Button("Reveal Notes File", systemImage: "doc") {
                    NSWorkspace.shared.activateFileViewerSelecting([store.fileURL])
                }
                Divider()
                SettingsLink {
                    Label("Settings…", systemImage: "gearshape")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 28, height: 28)
                    .background(.white.opacity(0.48), in: Circle())
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(8)
        .background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 13))
        .overlay {
            RoundedRectangle(cornerRadius: 13)
                .stroke(.white.opacity(0.65), lineWidth: 0.75)
        }
        .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    private var noteList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                ForEach(store.sections) { section in
                    let sectionNotes = filteredNotes.filter { $0.sectionID == section.id }
                    if !sectionNotes.isEmpty || searchText.isEmpty {
                        Section {
                            if sectionNotes.isEmpty {
                                Text("No notes yet")
                                    .font(.callout)
                                    .foregroundStyle(.tertiary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 16)
                            } else {
                                ForEach(sectionNotes) { note in
                                    NoteRow(
                                        note: note,
                                        isSelected: selectedIDs.contains(note.id),
                                        onSelect: { toggleSelection(note.id) }
                                    )
                                    .contextMenu { contextMenu(for: note) }
                                }
                            }
                        } header: {
                            HStack {
                                Text(section.name.uppercased())
                                    .font(.system(size: 11, weight: .semibold))
                                    .tracking(1.15)
                                    .foregroundStyle(.secondary)
                                Rectangle()
                                    .fill(.secondary.opacity(0.18))
                                    .frame(height: 1)
                                Spacer()
                                if store.sections.count > 1 {
                                    Menu {
                                        Button("Delete Section", role: .destructive) {
                                            store.deleteSection(section.id)
                                        }
                                    } label: {
                                        Image(systemName: "ellipsis")
                                            .foregroundStyle(.tertiary)
                                    }
                                    .menuStyle(.borderlessButton)
                                    .fixedSize()
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .overlay {
            if !searchText.isEmpty && filteredNotes.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            Menu {
                ForEach(store.sections) { section in
                    Button(section.name) { store.activeSectionID = section.id }
                }
            } label: {
                Image(systemName: "circle")
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            TextField("Add a note or a prompt", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .focused($isComposerFocused)
                .onSubmit(addDraft)

            if !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button(action: addDraft) {
                    Image(systemName: "arrow.up.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
            }
        }
        .padding(13)
        .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 13))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(isComposerFocused ? Color.accentColor : .white.opacity(0.72), lineWidth: isComposerFocused ? 1.5 : 0.75)
        }
        .shadow(color: .black.opacity(0.1), radius: 12, y: 5)
        .padding(12)
    }

    @ViewBuilder
    private func contextMenu(for note: CopperNote) -> some View {
        let ids = selectedIDs.contains(note.id) ? selectedIDs : [note.id]
        Button("Copy", systemImage: "doc.on.doc") { store.copy(ids, asList: false) }
            .keyboardShortcut("c")
        Button("Copy as List", systemImage: "list.number") { store.copy(ids, asList: true) }
            .keyboardShortcut("c", modifiers: [.command, .shift])
        Divider()
        Button(note.isDone ? "Mark as Not Done" : "Mark as Done", systemImage: "checkmark.circle") {
            store.toggleDone(ids)
        }
        Button("Expand", systemImage: "arrow.up.left.and.arrow.down.right") {
            expandedNote = note
        }
        Button("Edit", systemImage: "pencil") { editingNote = note }
        if ids.count > 1 {
            Button("Merge Notes", systemImage: "arrow.triangle.merge") {
                if let mergedID = store.merge(ids) { selectedIDs = [mergedID] }
            }
            .keyboardShortcut("m", modifiers: [.command, .shift])
        }
        Menu("Move to", systemImage: "folder") {
            ForEach(store.sections) { section in
                Button(section.name) {
                    store.move(ids, to: section.id)
                    selectedIDs.subtract(ids)
                }
            }
        }
        Divider()
        Button("Delete", systemImage: "trash", role: .destructive) {
            store.delete(ids)
            selectedIDs.subtract(ids)
        }
    }

    private func toggleSelection(_ id: UUID) {
        if selectedIDs.contains(id) { selectedIDs.remove(id) }
        else { selectedIDs.insert(id) }
    }

    private func addDraft() {
        store.addNote(draft)
        draft = ""
    }
}

private struct NoteRow: View {
    let note: CopperNote
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : (note.isDone ? "checkmark.circle" : "circle"))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .padding(.top, 2)
                Text(.init(note.text))
                    .font(.system(size: 14))
                    .foregroundStyle(note.isDone ? .secondary : .primary)
                    .strikethrough(note.isDone)
                    .lineLimit(7)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(13)
            .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : .white.opacity(0.62), lineWidth: isSelected ? 1.75 : 0.75)
            }
            .shadow(color: .black.opacity(isSelected ? 0.1 : 0.06), radius: isSelected ? 8 : 5, y: 2)
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

private struct NoteEditor: View {
    @Environment(\.dismiss) private var dismiss
    let note: CopperNote
    let title: String
    let onSave: (String) -> Void
    @State private var text: String

    init(note: CopperNote, title: String, onSave: @escaping (String) -> Void) {
        self.note = note
        self.title = title
        self.onSave = onSave
        _text = State(initialValue: note.text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.headline)
            TextEditor(text: $text)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") {
                    onSave(text)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 480, height: 340)
    }
}

private struct ExpandedNote: View {
    @Environment(\.dismiss) private var dismiss
    let note: CopperNote

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Note").font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            ScrollView {
                Text(.init(note.text))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(24)
        .frame(width: 560, height: 440)
    }
}

private struct NewSectionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    let onCreate: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Section").font(.headline)
            TextField("Section name", text: $name)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Create") {
                    onCreate(name)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 360)
    }
}

struct SettingsView: View {
    @EnvironmentObject private var store: CopperStore

    var body: some View {
        Form {
            Picker("Capture shortcut", selection: Binding(
                get: { store.captureShortcut },
                set: { store.setCaptureShortcut($0) }
            )) {
                ForEach(CaptureShortcut.allCases) { shortcut in
                    Text(shortcut.title).tag(shortcut)
                }
            }

            VStack(alignment: .leading) {
                HStack {
                    Text("Double-tap speed")
                    Spacer()
                    Text("\(store.captureInterval, format: .number.precision(.fractionLength(2)))s")
                        .foregroundStyle(.secondary)
                }
                Slider(value: Binding(
                    get: { store.captureInterval },
                    set: { store.setCaptureInterval($0) }
                ), in: 0.25...0.7)
            }

            LabeledContent("Storage") {
                Button("Reveal Notes File") {
                    NSWorkspace.shared.activateFileViewerSelecting([store.fileURL])
                }
            }

            LabeledContent("Privacy") {
                Text("Local only. No account or tracking.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 480, height: 300)
    }
}

struct CaptureToast: View {
    var body: some View {
        Label("Captured", systemImage: "checkmark")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(.black.opacity(0.88), in: Capsule())
    }
}

private struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .sidebar
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
