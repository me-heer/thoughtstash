import Foundation

/// The list's keyboard selection, kept deliberately separate from the view so the
/// navigation rules can be tested directly.
///
/// Selection is anchored the way every list on the platform is: `cursor` is the note
/// the arrows move, `anchor` is where a ⇧-extended range started, and `selected` is
/// everything between them.
struct NoteSelectionState: Equatable {
    var selected: Set<UUID> = []
    var cursor: UUID?
    var anchor: UUID?

    static let empty = NoteSelectionState()

    static func single(_ id: UUID) -> NoteSelectionState {
        NoteSelectionState(selected: [id], cursor: id, anchor: id)
    }
}

enum NoteSelection {
    enum Outcome: Equatable {
        case selection(NoteSelectionState)
        /// Stepping down past the last note leaves the list rather than sticking to it.
        case focusComposer
    }

    static func moving(
        _ state: NoteSelectionState,
        by offset: Int,
        extending: Bool,
        in visible: [UUID]
    ) -> Outcome {
        guard !visible.isEmpty else { return .selection(state) }

        let currentID = state.cursor ?? visible.first(where: { state.selected.contains($0) })
        let currentIndex = currentID.flatMap { visible.firstIndex(of: $0) }

        if !extending, let currentIndex, currentIndex == visible.count - 1, offset > 0 {
            return .focusComposer
        }

        guard let currentIndex else {
            // Nothing selected yet: enter the list from whichever end we came from.
            let entryIndex = offset < 0 ? visible.count - 1 : 0
            return .selection(.single(visible[entryIndex]))
        }

        let targetIndex = min(max(currentIndex + offset, 0), visible.count - 1)
        guard extending else { return .selection(.single(visible[targetIndex])) }

        let anchorIndex = state.anchor.flatMap { visible.firstIndex(of: $0) } ?? currentIndex
        let range = min(anchorIndex, targetIndex)...max(anchorIndex, targetIndex)
        return .selection(NoteSelectionState(
            selected: Set(range.map { visible[$0] }),
            cursor: visible[targetIndex],
            anchor: visible[anchorIndex]
        ))
    }
}
