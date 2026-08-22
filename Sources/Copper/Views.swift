import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: CopperStore
    @State private var searchText = ""
    @State private var draft = ""
    @State private var selectedIDs = Set<UUID>()
    @State private var editorContext: NoteEditorContext?
    @State private var expandedNote: CopperNote?
    @State private var isAddingSection = false
    @State private var isShowingShortcutGuide = false
    @State private var collapsedSections = Set<UUID>()
    @State private var isComposerFocused = false
    @State private var composerFocusRequest = UUID()
    @FocusState private var isSearchFocused: Bool

    private var searchQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredNotes: [CopperNote] {
        guard !searchQuery.isEmpty else { return store.notes }
        return store.notes.filter {
            $0.text.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    private var orderedVisibleNotes: [CopperNote] {
        store.sections.flatMap { section -> [CopperNote] in
            guard !searchQuery.isEmpty || !collapsedSections.contains(section.id) else { return [] }
            return filteredNotes.filter { $0.sectionID == section.id }
        }
    }

    private var defaultSectionID: UUID {
        store.inboxSection?.id ?? store.activeSectionID
    }

    var body: some View {
        let sheeted = withSheets(rootStack)
        let lifecycled = withLifecycleNotifications(sheeted)
        let handled = withSelectionNotifications(lifecycled)
        return handled
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
            .sheet(item: $editorContext) { context in
                NoteEditor(
                    note: context.note,
                    sections: store.sections,
                    initialSectionID: defaultSectionID
                ) { markdown, sectionID in
                    if let note = context.note {
                        withAnimation(.snappy(duration: 0.2)) {
                            store.updateNote(
                                id: note.id,
                                text: markdown,
                                sectionID: sectionID
                            )
                        }
                    } else {
                        withAnimation(.snappy(duration: 0.28)) {
                            store.addNote(
                                markdown,
                                sectionID: sectionID
                            )
                        }
                    }
                }
            }
            .sheet(item: $expandedNote) { note in
                ExpandedNote(note: note)
            }
            .sheet(isPresented: $isAddingSection) {
                NewSectionView { store.addSection(named: $0) }
            }
            .sheet(isPresented: $isShowingShortcutGuide) {
                ShortcutGuideView()
            }
    }

    @ViewBuilder
    private func withLifecycleNotifications(_ content: some View) -> some View {
        content
            .onAppear {
                DispatchQueue.main.async { requestComposerFocus() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .copperFocusComposer)) { _ in
                DispatchQueue.main.async { requestComposerFocus() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .copperNewNote)) { _ in
                editorContext = NoteEditorContext(note: nil)
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
            .onReceive(NotificationCenter.default.publisher(for: .copperRevealNotesFile)) { _ in
                NSWorkspace.shared.activateFileViewerSelecting([store.fileURL])
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
                if !searchQuery.isEmpty {
                    Button {
                        searchText = ""
                        isSearchFocused = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear search")
                }
            }
            .padding(.horizontal, 11)
            .frame(height: 34)
            .glassEffect(Glass.regular.tint(isSearchFocused ? Color.accentColor.opacity(0.15) : nil), in: Capsule())
            .animation(.easeOut(duration: 0.18), value: isSearchFocused)

            Menu {
                Button("New Note…", systemImage: "square.and.pencil") {
                    editorContext = NoteEditorContext(note: nil)
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
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(store.sections) { section in
                        let sectionNotes = filteredNotes.filter { $0.sectionID == section.id }
                        let isCollapsed = searchQuery.isEmpty && collapsedSections.contains(section.id)
                        if !sectionNotes.isEmpty || searchQuery.isEmpty {
                            Section {
                                if !isCollapsed {
                                    Group {
                                        if sectionNotes.isEmpty {
                                            Text("No notes yet")
                                                .font(.callout)
                                                .foregroundStyle(.tertiary)
                                                .frame(maxWidth: .infinity, alignment: .center)
                                                .padding(.vertical, 16)
                                        } else {
                                            LazyVStack(spacing: 7) {
                                                ForEach(sectionNotes) { note in
                                                    NoteRow(
                                                        note: note,
                                                        isSelected: selectedIDs.contains(note.id),
                                                        onSelect: { toggleSelection(note.id) }
                                                    )
                                                    .id(note.id)
                                                    .transition(.asymmetric(
                                                        insertion: .scale(scale: 0.92).combined(with: .opacity),
                                                        removal: .opacity
                                                    ))
                                                    .contextMenu { contextMenu(for: note) }
                                                }
                                            }
                                        }
                                    }
                                    .transition(.move(edge: .top).combined(with: .opacity))
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
            .onChange(of: primarySelectedNote?.id) { _, selectedID in
                guard let selectedID else { return }
                withAnimation(.easeOut(duration: 0.16)) {
                    proxy.scrollTo(selectedID, anchor: .center)
                }
            }
        }
        .overlay {
            if !searchQuery.isEmpty && filteredNotes.isEmpty {
                ContentUnavailableView.search(text: searchQuery)
            }
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .bottom, spacing: 10) {
                ZStack(alignment: .topLeading) {
                    if draft.isEmpty {
                        Text("Add a note or a prompt")
                            .font(.system(size: 14))
                            .foregroundStyle(.tertiary)
                            .allowsHitTesting(false)
                            .padding(.top, 1)
                    }
                    ComposerMarkdownEditor(
                        text: $draft,
                        focusRequest: composerFocusRequest,
                        onFocusChange: { isComposerFocused = $0 },
                        onSubmit: addDraft
                    )
                }
                .frame(height: 48)

                if !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button(action: addDraft) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.tint)
                    .hoverGlow(radius: 10)
                    .transition(.scale.combined(with: .opacity))
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
            editorContext = NoteEditorContext(note: note)
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
        leaveTextInput()
        if selectedIDs.contains(id) { selectedIDs.remove(id) }
        else { selectedIDs.insert(id) }
    }

    private var primarySelectedNote: CopperNote? {
        orderedVisibleNotes.first { selectedIDs.contains($0.id) }
    }

    private func selectRelative(_ offset: Int) {
        guard !orderedVisibleNotes.isEmpty else { return }
        leaveTextInput()
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

    private func leaveTextInput() {
        isComposerFocused = false
        isSearchFocused = false
        DispatchQueue.main.async {
            NSApp.keyWindow?.makeFirstResponder(nil)
        }
    }

    private func editPrimarySelection() {
        guard let note = primarySelectedNote else { return }
        editorContext = NoteEditorContext(note: note)
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

    private func requestComposerFocus() {
        composerFocusRequest = UUID()
    }

    private func addDraft() {
        withAnimation(.snappy(duration: 0.28)) {
            store.addNote(draft, sectionID: defaultSectionID)
        }
        draft = ""
        requestComposerFocus()
    }
}

private struct NoteRow: View {
    let note: CopperNote
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 4) {
                Text(.init(note.headline))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(note.isDone ? .secondary : .primary)
                    .strikethrough(note.isDone)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if !note.bodyPreview.isEmpty {
                    MarkdownPreview(markdown: note.bodyPreview, compact: true)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .strikethrough(note.isDone)
                        .lineLimit(4)
                        .multilineTextAlignment(.leading)
                        .frame(maxHeight: 72, alignment: .top)
                        .clipped()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .glassEffect(
                Glass.regular
                    .tint(Color(nsColor: .controlBackgroundColor).opacity(0.2))
                    .interactive(),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 1.5)
            }
            .animation(.easeOut(duration: 0.15), value: isSelected)
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

private struct ExpandedNote: View {
    @Environment(\.dismiss) private var dismiss
    let note: CopperNote

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(note.headline).font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .buttonStyle(.glass)
            }
            ScrollView {
                MarkdownPreview(markdown: note.text)
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
