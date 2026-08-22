import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: CopperStore
    @State private var searchText = ""
    @State private var draft = ""
    @State private var showsMarkdownPreview = false
    @State private var selectedIDs = Set<UUID>()
    @State private var editingNote: CopperNote?
    @State private var expandedNote: CopperNote?
    @State private var isAddingSection = false
    @State private var longformContext: LongformEditorContext?
    @State private var isShowingShortcutGuide = false
    @State private var collapsedSections = Set<UUID>()
    @Namespace private var noteNamespace
    @FocusState private var isComposerFocused: Bool
    @FocusState private var isSearchFocused: Bool

    private var filteredNotes: [CopperNote] {
        guard !searchText.isEmpty else { return store.notes }
        return store.notes.filter {
            $0.text.localizedCaseInsensitiveContains(searchText)
                || ($0.title?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    private var orderedVisibleNotes: [CopperNote] {
        store.sections.flatMap { section in
            filteredNotes.filter { $0.sectionID == section.id }
        }
    }

    var body: some View {
        let sheeted = withSheets(rootStack)
        let lifecycled = withLifecycleNotifications(sheeted)
        let handled = withSelectionNotifications(lifecycled)
        return handled
            .onChange(of: draft) { _, newValue in
                let shouldShow = containsMarkdown(newValue)
                if shouldShow != showsMarkdownPreview {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        showsMarkdownPreview = shouldShow
                    }
                }
            }
            .animation(.snappy(duration: 0.2), value: selectedIDs)
    }

    private var rootStack: some View {
        ZStack {
            Color.clear
                .glassEffect(.regular, in: Rectangle())
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                noteList
                composer
            }
        }
        .frame(minWidth: 360, minHeight: 480)
    }

    @ViewBuilder
    private func withSheets(_ content: some View) -> some View {
        content
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
            .sheet(item: $longformContext) { context in
                LongformEditor(
                    note: context.note,
                    sections: store.sections,
                    initialSectionID: store.activeSectionID
                ) { title, markdown, sectionID in
                    if let note = context.note {
                        store.updateNote(
                            id: note.id,
                            text: markdown,
                            title: title,
                            kind: .longform,
                            sectionID: sectionID
                        )
                    } else {
                        store.addNote(
                            markdown,
                            sectionID: sectionID,
                            title: title,
                            kind: .longform
                        )
                    }
                }
            }
            .sheet(isPresented: $isShowingShortcutGuide) {
                ShortcutGuideView()
            }
    }

    @ViewBuilder
    private func withLifecycleNotifications(_ content: some View) -> some View {
        content
            .onAppear {
                DispatchQueue.main.async { isComposerFocused = true }
            }
            .onReceive(NotificationCenter.default.publisher(for: .copperFocusComposer)) { _ in
                DispatchQueue.main.async { isComposerFocused = true }
            }
            .onReceive(NotificationCenter.default.publisher(for: .copperNewLongform)) { _ in
                longformContext = LongformEditorContext(note: nil)
            }
            .onReceive(NotificationCenter.default.publisher(for: .copperNewSection)) { _ in
                isAddingSection = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .copperFocusSearch)) { _ in
                isSearchFocused = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .copperShowShortcutGuide)) { _ in
                isShowingShortcutGuide = true
            }
    }

    @ViewBuilder
    private func withSelectionNotifications(_ content: some View) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .copperSelectNext)) { _ in selectRelative(1) }
            .onReceive(NotificationCenter.default.publisher(for: .copperSelectPrevious)) { _ in selectRelative(-1) }
            .onReceive(NotificationCenter.default.publisher(for: .copperCopySelected)) { _ in store.copy(selectedIDs, asList: false) }
            .onReceive(NotificationCenter.default.publisher(for: .copperCopySelectedAsList)) { _ in store.copy(selectedIDs, asList: true) }
            .onReceive(NotificationCenter.default.publisher(for: .copperToggleDone)) { _ in
                withAnimation(.bouncy(duration: 0.35, extraBounce: 0.1)) { store.toggleDone(selectedIDs) }
            }
            .onReceive(NotificationCenter.default.publisher(for: .copperEditSelected)) { _ in editPrimarySelection() }
            .onReceive(NotificationCenter.default.publisher(for: .copperExpandSelected)) { _ in expandedNote = primarySelectedNote }
            .onReceive(NotificationCenter.default.publisher(for: .copperMergeSelected)) { _ in mergeSelection() }
            .onReceive(NotificationCenter.default.publisher(for: .copperMoveToNextSection)) { _ in moveSelectionToNextSection() }
            .onReceive(NotificationCenter.default.publisher(for: .copperDeleteSelected)) { _ in deleteSelection() }
            .onReceive(NotificationCenter.default.publisher(for: .copperDeleteActiveSection)) { _ in
                withAnimation(.snappy(duration: 0.28)) { store.deleteSection(store.activeSectionID) }
            }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search", text: $searchText)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
            }
            .padding(.horizontal, 11)
            .frame(height: 34)
            .glassEffect(Glass.regular.tint(isSearchFocused ? Color.accentColor.opacity(0.15) : nil), in: Capsule())
            .animation(.easeOut(duration: 0.18), value: isSearchFocused)

            Menu {
                Button("New Longform Note…", systemImage: "doc.richtext") {
                    longformContext = LongformEditorContext(note: nil)
                }
                Button("New Section…", systemImage: "folder.badge.plus") {
                    isAddingSection = true
                }
                Button("Keyboard Shortcuts…", systemImage: "keyboard") {
                    isShowingShortcutGuide = true
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
                    .frame(width: 34, height: 34)
                    .glassEffect(Glass.regular.interactive(), in: Circle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .hoverGlow(radius: 10)
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    private var noteList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                ForEach(store.sections) { section in
                    let sectionNotes = filteredNotes.filter { $0.sectionID == section.id }
                    let isCollapsed = collapsedSections.contains(section.id)
                    if !sectionNotes.isEmpty || searchText.isEmpty {
                        Section {
                            if !isCollapsed {
                                if sectionNotes.isEmpty {
                                    VStack(spacing: 6) {
                                        Text("No notes yet")
                                            .font(.callout)
                                            .foregroundStyle(.tertiary)
                                        ShortcutHint(notification: .copperFocusComposer, label: "Add one")
                                    }
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 16)
                                } else {
                                    ForEach(sectionNotes) { note in
                                        NoteRow(
                                            note: note,
                                            isSelected: selectedIDs.contains(note.id),
                                            onSelect: { toggleSelection(note.id) }
                                        )
                                        .matchedGeometryEffect(id: note.id, in: noteNamespace)
                                        .transition(.asymmetric(
                                            insertion: .scale(scale: 0.92).combined(with: .opacity),
                                            removal: .opacity
                                        ))
                                        .contextMenu { contextMenu(for: note) }
                                    }
                                }
                            }
                        } header: {
                            HStack {
                                Button {
                                    withAnimation(.snappy(duration: 0.25)) {
                                        if isCollapsed { collapsedSections.remove(section.id) }
                                        else { collapsedSections.insert(section.id) }
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 9, weight: .bold))
                                            .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                                        Text(section.name.uppercased())
                                            .font(.system(size: 11, weight: .semibold))
                                            .tracking(1.15)
                                    }
                                    .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                                .animation(.easeInOut(duration: 0.2), value: isCollapsed)

                                Rectangle()
                                    .fill(.secondary.opacity(0.18))
                                    .frame(height: 1)
                                Spacer()
                                if store.sections.count > 1 {
                                    Menu {
                                        Button("Delete Section", role: .destructive) {
                                            withAnimation(.snappy(duration: 0.28)) {
                                                store.deleteSection(section.id)
                                            }
                                        }
                                    } label: {
                                        Image(systemName: "ellipsis")
                                            .foregroundStyle(.tertiary)
                                    }
                                    .menuStyle(.borderlessButton)
                                    .fixedSize()
                                    .hoverGlow(radius: 8)
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
        VStack(alignment: .leading, spacing: 9) {
            if showsMarkdownPreview {
                ScrollView {
                    MarkdownPreview(markdown: draft, compact: true)
                        .font(.system(size: 13))
                        .padding(.horizontal, 3)
                }
                .frame(maxHeight: 110)
                .transition(.opacity.combined(with: .move(edge: .top)))
                Divider()
            }

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
                .menuIndicator(.hidden)
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
                    .hoverGlow(radius: 10)
                    .transition(.scale.combined(with: .opacity))
                } else if !isComposerFocused {
                    ShortcutHint(notification: .copperFocusComposer)
                        .transition(.opacity)
                }
            }
        }
        .padding(13)
        .glassEffect(
            Glass.regular.tint(isComposerFocused ? Color.accentColor.opacity(0.08) : nil).interactive(),
            in: RoundedRectangle(cornerRadius: 13)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(isComposerFocused ? Color.accentColor : .clear, lineWidth: 1.5)
        }
        .animation(.easeOut(duration: 0.18), value: isComposerFocused)
        .animation(.easeOut(duration: 0.16), value: draft.isEmpty)
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
            withAnimation(.bouncy(duration: 0.35, extraBounce: 0.1)) { store.toggleDone(ids) }
        }
        Button("Expand", systemImage: "arrow.up.left.and.arrow.down.right") {
            expandedNote = note
        }
        Button("Edit", systemImage: "pencil") {
            if note.isLongform { longformContext = LongformEditorContext(note: note) }
            else { editingNote = note }
        }
        if ids.count > 1 {
            Button("Merge Notes", systemImage: "arrow.triangle.merge") {
                withAnimation(.snappy(duration: 0.28)) {
                    if let mergedID = store.merge(ids) { selectedIDs = [mergedID] }
                }
            }
            .keyboardShortcut("m", modifiers: [.command, .shift])
        }
        Menu("Move to", systemImage: "folder") {
            ForEach(store.sections) { section in
                Button(section.name) {
                    withAnimation(.snappy(duration: 0.28)) {
                        store.move(ids, to: section.id)
                        selectedIDs.subtract(ids)
                    }
                }
            }
        }
        Divider()
        Button("Delete", systemImage: "trash", role: .destructive) {
            withAnimation(.snappy(duration: 0.28)) {
                store.delete(ids)
                selectedIDs.subtract(ids)
            }
        }
    }

    private func toggleSelection(_ id: UUID) {
        if selectedIDs.contains(id) { selectedIDs.remove(id) }
        else { selectedIDs.insert(id) }
    }

    private var primarySelectedNote: CopperNote? {
        orderedVisibleNotes.first { selectedIDs.contains($0.id) }
    }

    private func selectRelative(_ offset: Int) {
        guard !orderedVisibleNotes.isEmpty else { return }
        let currentIndex = primarySelectedNote.flatMap { current in
            orderedVisibleNotes.firstIndex(where: { $0.id == current.id })
        }
        let nextIndex: Int
        if let currentIndex {
            nextIndex = min(max(currentIndex + offset, 0), orderedVisibleNotes.count - 1)
        } else {
            nextIndex = offset < 0 ? orderedVisibleNotes.count - 1 : 0
        }
        selectedIDs = [orderedVisibleNotes[nextIndex].id]
    }

    private func editPrimarySelection() {
        guard let note = primarySelectedNote else { return }
        if note.isLongform { longformContext = LongformEditorContext(note: note) }
        else { editingNote = note }
    }

    private func mergeSelection() {
        withAnimation(.snappy(duration: 0.28)) {
            if let mergedID = store.merge(selectedIDs) { selectedIDs = [mergedID] }
        }
    }

    private func moveSelectionToNextSection() {
        guard !selectedIDs.isEmpty,
              let currentSectionID = primarySelectedNote?.sectionID,
              let currentIndex = store.sections.firstIndex(where: { $0.id == currentSectionID }) else { return }
        let next = store.sections[(currentIndex + 1) % store.sections.count]
        withAnimation(.snappy(duration: 0.28)) {
            store.move(selectedIDs, to: next.id)
        }
    }

    private func deleteSelection() {
        withAnimation(.snappy(duration: 0.28)) {
            store.delete(selectedIDs)
            selectedIDs.removeAll()
        }
    }

    private func containsMarkdown(_ text: String) -> Bool {
        text.contains("**") || text.contains("*") || text.contains("# ")
            || text.contains("- ") || text.contains("> ") || text.contains("```")
    }

    private func addDraft() {
        withAnimation(.snappy(duration: 0.28)) {
            store.addNote(draft)
        }
        draft = ""
    }
}

private struct NoteRow: View {
    let note: CopperNote
    let isSelected: Bool
    let onSelect: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : (note.isDone ? "checkmark.circle" : "circle"))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .padding(.top, 2)
                    .symbolEffect(.bounce, value: note.isDone)
                VStack(alignment: .leading, spacing: 5) {
                    if note.isLongform {
                        Label(note.title ?? "Untitled", systemImage: "doc.richtext")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    RichNoteText(note: note)
                        .font(.system(size: 14))
                        .foregroundStyle(note.isDone ? .secondary : .primary)
                        .strikethrough(note.isDone)
                        .lineLimit(note.isLongform ? 4 : 7)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if isHovering || isSelected {
                    VStack(alignment: .trailing, spacing: 4) {
                        ShortcutHint(notification: .copperEditSelected)
                        ShortcutHint(notification: .copperToggleDone)
                    }
                    .transition(.opacity)
                }
            }
            .padding(13)
            .glassEffect(Glass.regular.interactive(), in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 1.75)
            }
            .animation(.easeOut(duration: 0.15), value: isSelected)
            .animation(.easeOut(duration: 0.15), value: isHovering)
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
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
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 8))
            if !text.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("PREVIEW")
                        .font(.caption.weight(.semibold))
                        .tracking(1)
                        .foregroundStyle(.secondary)
                    ScrollView {
                        MarkdownPreview(markdown: text, compact: true)
                            .padding(8)
                    }
                }
                .frame(maxHeight: 130)
                .transition(.opacity)
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .buttonStyle(.glass)
                Button("Save") {
                    onSave(text)
                    dismiss()
                }
                .buttonStyle(.glassProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 480, height: 340)
        .animation(.easeOut(duration: 0.18), value: text.isEmpty)
    }
}

private struct ExpandedNote: View {
    @Environment(\.dismiss) private var dismiss
    let note: CopperNote

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(note.title ?? "Note").font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .buttonStyle(.glass)
            }
            ScrollView {
                if note.isLongform {
                    MarkdownPreview(markdown: note.text)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    RichNoteText(note: note)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(24)
        .frame(width: 560, height: 440)
    }
}

private struct LongformEditorContext: Identifiable {
    let id = UUID()
    let note: CopperNote?
}

private struct RichNoteText: View {
    let note: CopperNote

    var body: some View {
        if let data = note.richTextRTF,
           let richText = RichTextCodec.attributedString(fromRTF: data) {
            Text(AttributedString(richText))
        } else {
            Text(.init(note.text))
        }
    }
}

private struct NewSectionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @FocusState private var isNameFocused: Bool
    let onCreate: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Section").font(.headline)
            TextField("Section name", text: $name)
                .focused($isNameFocused)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .buttonStyle(.glass)
                Button("Create") {
                    onCreate(name)
                    dismiss()
                }
                .buttonStyle(.glassProminent)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 360)
        .onAppear { isNameFocused = true }
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
            .glassEffect(Glass.regular.tint(.black.opacity(0.35)), in: Capsule())
    }
}
