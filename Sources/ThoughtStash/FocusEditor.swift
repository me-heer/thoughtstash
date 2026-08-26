import AppKit
import SwiftUI

/// Focus mode: the editor's chrome drops away, the text takes a capped column in the
/// middle of a scrimmed glass window, and one hairline bar comes back when it is reached
/// for — pointer near the top edge, ⌘ held, or the first couple of seconds after entering,
/// so the way out is never a secret.
///
/// Shared by `NoteEditor` and the `ZenLab` storybook, so the shipped mode and the design
/// artifact are the same view.
struct FocusEditorSurface: View {
    @Binding var markdown: String
    @Binding var sectionID: UUID
    let sections: [StashSection]
    let focusRequest: UUID
    /// True while ⌘ is held; the host owns the flags monitor.
    let isCommandHeld: Bool
    let onExit: () -> Void
    let onSave: () -> Void

    @Environment(\.appFontTheme) private var fontTheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPointerNearTop = false
    @State private var isIntroducing = true
    @State private var introTask: Task<Void, Never>?

    private var showsChrome: Bool {
        isPointerNearTop || isCommandHeld || isIntroducing
    }

    var body: some View {
        ZStack {
            Color.clear
                .glassEffect(.regular, in: Rectangle())
                .ignoresSafeArea()
            // The scrim is what makes it a curtain rather than a new window: the panel is
            // still back there, just pushed out of mind.
            Color.black.opacity(0.34)
                .ignoresSafeArea()

            LiveMarkdownEditor(
                text: $markdown,
                focusRequest: focusRequest,
                fontTheme: fontTheme,
                fontSize: 19,
                inset: NSSize(width: 0, height: 34)
            )
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
            .padding(.top, 46)
            .padding(.bottom, 30)
        }
        .overlay(alignment: .top) { bar }
        .overlay(alignment: .bottom) {
            FocusKeyHint(keys: "⎋", label: "leave focus")
                .padding(.bottom, 14)
                .opacity(showsChrome ? 1 : 0)
        }
        .onContinuousHover { phase in
            guard case .active(let point) = phase else {
                isPointerNearTop = false
                return
            }
            isPointerNearTop = point.y < 90
        }
        .animation(reduceMotion ? .none : .easeOut(duration: 0.22), value: showsChrome)
        .onAppear {
            introTask?.cancel()
            introTask = Task {
                try? await Task.sleep(for: .seconds(2.2))
                guard !Task.isCancelled else { return }
                isIntroducing = false
            }
        }
        .onDisappear { introTask?.cancel() }
    }

    private var bar: some View {
        HStack(spacing: 12) {
            Picker("Section", selection: $sectionID) {
                ForEach(sections) { section in Text(section.name).tag(section.id) }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .controlSize(.small)
            .font(.system(size: 11.5, weight: .medium))
            .fixedSize()

            Divider().frame(height: 11)

            FocusMeta(text: markdown)

            Spacer(minLength: 24)

            Button(action: onSave) {
                FocusKeyHint(keys: "⌘S", label: "save")
            }
            .buttonStyle(.plain)
            .disabled(markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Button(action: onExit) {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Leave focus mode")
        }
        .padding(.horizontal, 14)
        .frame(height: 34)
        .frame(maxWidth: 700)
        .glassEffect(.regular, in: Capsule())
        .padding(.top, 12)
        .opacity(showsChrome ? 1 : 0)
        .offset(y: showsChrome || reduceMotion ? 0 : -6)
    }
}

struct FocusMeta: View {
    let text: String

    private var words: Int {
        text.split { $0.isWhitespace || $0.isNewline }.count
    }

    var body: some View {
        HStack(spacing: 14) {
            Text("\(words) words")
            Text("\(text.count) characters")
        }
        .font(.system(size: 10.5, weight: .medium))
        .foregroundStyle(.tertiary)
        .monospacedDigit()
    }
}

struct FocusKeyHint: View {
    let keys: String
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            Text(keys)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
            Text(label)
                .font(.system(size: 10.5))
        }
        .foregroundStyle(.tertiary)
    }
}
