import SwiftUI

/// A single-pane markdown editor: shows a raw, editable `TextEditor` while focused (or
/// while empty, so there's always something to click into), and swaps to a tappable
/// rendered `MarkdownPreview` once focus leaves. Same rectangle throughout — no split or
/// stacked source/preview panes.
struct InlineMarkdownEditor: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    var compact: Bool = false

    var body: some View {
        Group {
            if isFocused.wrappedValue || text.isEmpty {
                TextEditor(text: $text)
                    .font(compact ? .system(size: 14) : .system(.body, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .focused(isFocused)
            } else {
                ScrollView {
                    MarkdownPreview(markdown: text, compact: compact)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture { isFocused.wrappedValue = true }
                }
            }
        }
        .padding(8)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 10))
        .animation(.easeOut(duration: 0.15), value: isFocused.wrappedValue)
    }
}
