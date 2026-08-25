import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: StashStore
    @State private var searchText = ""
    @State private var draft = ""
    @State private var selectedIDs = Set<UUID>()
    /// Keyboard selection is anchored: the cursor is the note the arrows move,
    /// the anchor is where a ⇧-extended range started.
    @State private var selectionCursor: UUID?
    @State private var selectionAnchor: UUID?
    @State private var editorContext: NoteEditorContext?
    @State private var expandedNote: StashNote?
    @State private var isAddingSection = false
    @State private var isShowingShortcutGuide = false
    @State private var collapsedSections = Set<UUID>()
    @State private var isComposerFocused = false
    @State private var saveTick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var composerFocusRequest = UUID()
    @State private var fontToast: AppFontTheme?
    @State private var fontToastTick = 0
    @FocusState private var isSearchFocused: Bool
    /// R6 header: the title row and the search field are the same row. Search is a
    /// button at rest and morphs into the field when opened, so the panel gets a
    /// permanent wordmark without spending a second row on it.
    @State private var isSearchExpanded = false
    @Namespace private var headerGlass

    private var searchQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredNotes: [StashNote] {
        guard !searchQuery.isEmpty else { return store.notes }
        return store.notes.filter {
            $0.text.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    private var orderedVisibleNotes: [StashNote] {
        store.sections.flatMap { section -> [StashNote] in
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
            .appFontTheme(store.fontTheme)
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
        .overlay(alignment: .top) {
            if let fontToast {
                Label("\(fontToast.title) · \(fontToast.faceName)", systemImage: "textformat")
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .glassEffect(.regular, in: Capsule())
                    .padding(.top, 16)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .allowsHitTesting(false)
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
            .onReceive(NotificationCenter.default.publisher(for: .stashFocusComposer)) { _ in
                DispatchQueue.main.async { requestComposerFocus() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .stashNewNote)) { _ in
                editorContext = NoteEditorContext(note: nil)
            }
            .onReceive(NotificationCenter.default.publisher(for: .stashNewSection)) { _ in
                isAddingSection = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .stashFocusSearch)) { _ in
                openSearch()
            }
            .onReceive(NotificationCenter.default.publisher(for: .stashEscape)) { notification in
                // Search first, panel second — Escape should undo the narrower thing.
                if isSearchExpanded {
                    closeSearch()
                } else {
                    // The monitor sends the window it matched; don't infer it from
                    // `keyWindow`, which can be nil or a different window entirely.
                    let panel = notification.object as? NSWindow ?? NSApp.keyWindow
                    panel?.performClose(nil)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .stashShowShortcutGuide)) { _ in
                isShowingShortcutGuide = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .stashRevealNotesFile)) { _ in
                NSWorkspace.shared.activateFileViewerSelecting([store.fileURL])
            }
            .onReceive(NotificationCenter.default.publisher(for: .stashCycleFont)) { _ in
                showFontToast(for: store.cycleFontTheme())
            }
    }

    @ViewBuilder
    private func withSelectionNotifications(_ content: some View) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .stashSelectNext)) { _ in selectRelative(1) }
            .onReceive(NotificationCenter.default.publisher(for: .stashSelectPrevious)) { _ in selectRelative(-1) }
            .onReceive(NotificationCenter.default.publisher(for: .stashExtendSelectionNext)) { _ in selectRelative(1, extending: true) }
            .onReceive(NotificationCenter.default.publisher(for: .stashExtendSelectionPrevious)) { _ in selectRelative(-1, extending: true) }
            .onReceive(NotificationCenter.default.publisher(for: .stashCopySelected)) { _ in store.copy(selectedIDs, asList: false) }
            .onReceive(NotificationCenter.default.publisher(for: .stashCopySelectedAsList)) { _ in store.copy(selectedIDs, asList: true) }
            .onReceive(NotificationCenter.default.publisher(for: .stashToggleDone)) { _ in
                withAnimation(.bouncy(duration: 0.35, extraBounce: 0.1)) { store.toggleDone(selectedIDs) }
            }
            .onReceive(NotificationCenter.default.publisher(for: .stashEditSelected)) { _ in editPrimarySelection() }
            .onReceive(NotificationCenter.default.publisher(for: .stashExpandSelected)) { _ in expandedNote = primarySelectedNote }
            .onReceive(NotificationCenter.default.publisher(for: .stashMergeSelected)) { _ in mergeSelection() }
            .onReceive(NotificationCenter.default.publisher(for: .stashMoveToNextSection)) { _ in moveSelection(bySections: 1) }
            .onReceive(NotificationCenter.default.publisher(for: .stashMoveToPreviousSection)) { _ in moveSelection(bySections: -1) }
            .onReceive(NotificationCenter.default.publisher(for: .stashDeleteSelected)) { _ in deleteSelection() }
            .onReceive(NotificationCenter.default.publisher(for: .stashDeleteActiveSection)) { _ in
                withAnimation(.snappy(duration: 0.28)) { store.deleteSection(store.activeSectionID) }
            }
    }

    private var topBar: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                if isSearchExpanded {
                    searchField
                } else {
                    wordmark
                    Spacer(minLength: 4)
                    searchButton
                }
                overflowMenu
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .animation(reduceMotion ? nil : .snappy(duration: 0.26), value: isSearchExpanded)
    }

    /// The one permanent appearance of the name in the window. Pinned to `.serif` with a
    /// nearer `.fontDesign` than the root's, so it keeps New York when the rest of the
    /// app is switched to sans or mono.
    private var wordmark: some View {
        Text("Thought Stash")
            .font(.system(size: 20, weight: .semibold))
            .fontDesign(.serif)
            .foregroundStyle(.primary.opacity(0.92))
            .lineLimit(1)
            .fixedSize()
            .transition(.opacity)
    }

    /// Shares `glassEffectID` with `searchField` so the circle grows into the capsule
    /// rather than one view crossfading into the other.
    private var searchButton: some View {
        Button(action: openSearch) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 34, height: 34)
                .glassEffect(Glass.regular.interactive(), in: Circle())
                .glassEffectID("search", in: headerGlass)
        }
        .buttonStyle(.plain)
        .help("Search (\(ShortcutMap.display(for: .stashFocusSearch) ?? "⌘F"))")
        .accessibilityLabel("Search")
        .hoverGlow(radius: 10)
    }

    private var searchField: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search", text: $searchText)
                .textFieldStyle(.plain)
                // Explicit design so the field is laid out on the metrics of the face it
                // actually renders in, rather than SF's.
                .font(.system(size: 13, design: store.fontTheme.design))
                // Optical centring, measured rather than guessed. A single-line field
                // centres its *line box*, but the eye centres the cap-height band, and
                // for a string with no descenders — "Search" — that band sits 5.5 device
                // px (2.75pt) above the capsule's centre. Nudging down by 3pt puts the
                // text's ink centre on the magnifier's, which measures dead centre.
                // `offset` rather than padding: this must not change the pill's height.
                .offset(y: 3)
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
        // Symmetric padding with a floor, rather than a hard height: a hard height centres
        // the field's frame, not its line box, and the three AppFontTheme faces don't share
        // metrics — New York in particular rides visibly high inside a fixed 34pt.
        // `minHeight` keeps the pill matched to the 34pt circular buttons beside it.
        .padding(.vertical, 8)
        .frame(minHeight: 34)
        .glassEffect(Glass.regular.tint(isSearchFocused ? Color.accentColor.opacity(0.15) : nil), in: Capsule())
        .glassEffectID("search", in: headerGlass)
        .animation(.easeOut(duration: 0.18), value: isSearchFocused)
        // Leaving an empty field puts the wordmark back; a field with a query stays open
        // so the filtered list keeps an obvious way out.
        .onChange(of: isSearchFocused) { _, focused in
            guard !focused, searchQuery.isEmpty else { return }
            closeSearch()
        }
    }

    private var overflowMenu: some View {
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
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 34, height: 34)
                .contentShape(Circle())
        }
        // `.borderlessButton` hands the label to AppKit, which rasterises the glyph
        // blurry, offsets it inside its own frame, and ignores `.glassEffect` entirely.
        // `.button` with a plain button style draws the label as written.
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .glassEffect(Glass.regular.interactive(), in: Circle())
        .hoverGlow(radius: 10)
    }

    private func openSearch() {
        if !isSearchExpanded {
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.26)) { isSearchExpanded = true }
        }
        isSearchFocused = true
    }

    private func closeSearch() {
        searchText = ""
        isSearchFocused = false
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.26)) { isSearchExpanded = false }
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
                                        if sectionNotes.isEmpty && !isStashEmpty {
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
                                                    .transition(reduceMotion ? .opacity : .stampDrop)
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
            .onChange(of: selectionCursor) { _, cursor in
                guard let cursor else { return }
                withAnimation(.easeOut(duration: 0.16)) {
                    proxy.scrollTo(cursor, anchor: .center)
                }
            }
        }
        .overlay {
            if !searchQuery.isEmpty && filteredNotes.isEmpty {
                ContentUnavailableView.search(text: searchQuery)
            } else if isStashEmpty {
                emptyStash
            }
        }
    }

    /// True only when there is nothing to show at all — not while a search is
    /// narrowing things down, which has its own empty state.
    private var isStashEmpty: Bool {
        store.notes.isEmpty && searchQuery.isEmpty
    }

    /// The one place the name appears in the window. It is the empty state rather
    /// than permanent chrome because the panel has to stay usable at 360 points
    /// wide, so a wordmark may not hold standing layout space — and this is the
    /// state where there is room to spare and something worth explaining.
    ///
    /// Pinned to `.serif` on purpose: the wordmark keeps its face even when the
    /// rest of the app is switched to mono or sans via `AppFontTheme`.
    private var emptyStash: some View {
        VStack(spacing: 8) {
            Text("Thought Stash")
                .font(.system(size: 25, weight: .semibold))
                // `.fontDesign` here, not `design:` on the font — the root's
                // `.fontDesign(theme.design)` overrides a design baked into a
                // descendant's font, but not a nearer `.fontDesign`.
                .fontDesign(.serif)
                .foregroundStyle(.primary.opacity(0.9))
            Text("Select text anywhere, then \(captureShortcut)")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 26)
        .padding(.bottom, 12)
        .transition(.opacity)
        .allowsHitTesting(false)
    }

    private var captureShortcut: String {
        ShortcutMap.entry(slug: "captureSelection")?.displayString ?? "Shift, Shift"
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
                        fontTheme: store.fontTheme,
                        onFocusChange: { focused in
                            isComposerFocused = focused
                            // Only one surface carries the accent outline at a time.
                            if focused { clearSelection() }
                        },
                        onSubmit: addDraft
                    )
                }
                .frame(height: 48)

                if !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("\u{23CE} SAVE")
                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                        .tracking(0.9)
                        .foregroundStyle(.tertiary)
                        .padding(.bottom, 3)
                        .transition(.opacity)

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
            StampRipple(trigger: saveTick)
                .clipShape(RoundedRectangle(cornerRadius: 13))
        }
        .overlay {
            // The focus ring snaps rather than fades — Stamp reads as mechanical.
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.accentColor.opacity(isComposerFocused ? 0.22 : 0), lineWidth: 5)
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isComposerFocused ? Color.accentColor : .clear, lineWidth: 2)
            }
            .animation(nil, value: isComposerFocused)
        }
        .stampPress(trigger: saveTick)
        .animation(.easeOut(duration: 0.12), value: isComposerFocused)
        .animation(.easeOut(duration: 0.16), value: draft.isEmpty)
        .padding(12)
    }

    @ViewBuilder
    private func contextMenu(for note: StashNote) -> some View {
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
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
        // A click re-anchors the keyboard selection wherever the pointer landed.
        selectionCursor = selectedIDs.contains(id) ? id : nil
        selectionAnchor = selectionCursor
    }

    private func clearSelection() {
        selectedIDs.removeAll()
        selectionCursor = nil
        selectionAnchor = nil
    }

    private var primarySelectedNote: StashNote? {
        orderedVisibleNotes.first { selectedIDs.contains($0.id) }
    }

    /// Moves the selection cursor by `offset`, extending the range from the anchor
    /// when asked. The rules themselves live in `NoteSelection` so they can be tested.
    private func selectRelative(_ offset: Int, extending: Bool = false) {
        let visible = orderedVisibleNotes.map(\.id)
        let state = NoteSelectionState(selected: selectedIDs, cursor: selectionCursor, anchor: selectionAnchor)

        switch NoteSelection.moving(state, by: offset, extending: extending, in: visible) {
        case .focusComposer:
            clearSelection()
            requestComposerFocus()
        case .selection(let next):
            leaveTextInput()
            selectedIDs = next.selected
            selectionCursor = next.cursor
            selectionAnchor = next.anchor
        }
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

    private func moveSelection(bySections offset: Int) {
        guard !selectedIDs.isEmpty,
              let currentSectionID = primarySelectedNote?.sectionID,
              let currentIndex = store.sections.firstIndex(where: { $0.id == currentSectionID }) else { return }
        let count = store.sections.count
        let destination = store.sections[((currentIndex + offset) % count + count) % count]
        withAnimation(.snappy(duration: 0.28)) {
            store.move(selectedIDs, to: destination.id)
        }
    }

    private func deleteSelection() {
        withAnimation(.snappy(duration: 0.28)) {
            store.delete(selectedIDs)
            clearSelection()
        }
    }

    /// The switch is silent otherwise — a chip names the face that just took over.
    private func showFontToast(for theme: AppFontTheme) {
        fontToastTick += 1
        let tick = fontToastTick
        withAnimation(.easeOut(duration: 0.18)) { fontToast = theme }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            guard fontToastTick == tick else { return }
            withAnimation(.easeOut(duration: 0.25)) { fontToast = nil }
        }
    }

    private func requestComposerFocus() {
        composerFocusRequest = UUID()
    }

    private func addDraft() {
        guard !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        saveTick += 1
        withAnimation(reduceMotion ? Stamp.cardFade : Stamp.cardDrop) {
            store.addNote(draft, sectionID: defaultSectionID)
        }
        draft = ""
        requestComposerFocus()
    }
}

private struct NoteRow: View {
    let note: StashNote
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 4) {
                Text(.init(note.headline))
                    .font(.system(size: 14))
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
    let note: StashNote

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
    @EnvironmentObject private var store: StashStore

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

            Picker("Font", selection: Binding(
                get: { store.fontTheme },
                set: { store.setFontTheme($0) }
            )) {
                ForEach(AppFontTheme.allCases) { theme in
                    Text(theme.title)
                        .fontDesign(theme.design)
                        .tag(theme)
                }
            }
            .pickerStyle(.segmented)

            Toggle("Show in menu bar", isOn: Binding(
                get: { store.showsMenuBarItem },
                set: { store.setShowsMenuBarItem($0) }
            ))

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
        .appFontTheme(store.fontTheme)
        .padding()
        .frame(width: 480, height: 340)
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
