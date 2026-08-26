import AppKit
import SwiftUI

/// Four takes on a distraction-free writing surface, kept side by side in `ZenLab`
/// (`swift run ThoughtStash --zen-lab`) so they can be compared with real text in them
/// before one is wired into the panel. Nothing here is reachable from the shipping UI yet.
enum ZenVariant: String, CaseIterable, Identifiable {
    /// Full-window overlay over the existing editor. Chrome is hidden until you reach for it.
    case curtain
    /// A separate resizable window that can stay open beside other apps.
    case desk
    /// Typewriter scrolling with everything but the current block faded out.
    case spotlight
    /// The panel's own composer growing upward into the whole panel — no new window.
    case bloom

    var id: String { rawValue }

    var index: Int { (Self.allCases.firstIndex(of: self) ?? 0) + 1 }

    var title: String {
        switch self {
        case .curtain: return "Curtain"
        case .desk: return "Desk"
        case .spotlight: return "Spotlight"
        case .bloom: return "Bloom"
        }
    }

    var tagline: String {
        switch self {
        case .curtain: return "Full-window overlay, chrome on demand — shipped"
        case .desk: return "Its own window, quiet permanent status line"
        case .spotlight: return "Typewriter scroll, everything else dimmed"
        case .bloom: return "The composer grows into the whole panel"
        }
    }

    var entry: String {
        switch self {
        case .curtain: return "⇧⌘F from the note editor"
        case .desk: return "⇧⌘F from anywhere, or ⌘E on a note"
        case .spotlight: return "A setting inside Curtain or Desk, not a fifth mode"
        case .bloom: return "⇧⌘F while the composer has focus"
        }
    }

    var exit: String {
        switch self {
        case .curtain: return "⎋ back to the editor, ⌘S saves and closes both"
        case .desk: return "⌘S saves, ⌘W closes, ⎋ does nothing (it's a real window)"
        case .spotlight: return "Inherits its host's exit"
        case .bloom: return "⎋ collapses back to the composer, ⏎ still saves"
        }
    }

    var cost: String {
        switch self {
        case .curtain: return "One overlay state on NoteEditor. No window plumbing, no new save path."
        case .desk: return "A second NSWindowController, its own dirty-state and restore-on-quit handling."
        case .spotlight: return "Text-storage dimming plus caret pinning; both already prototyped in LiveMarkdownEditor."
        case .bloom: return "Panel-local. Reuses the composer's draft and its Return-to-save flow verbatim."
        }
    }

    @ViewBuilder
    func view(text: Binding<String>) -> some View {
        switch self {
        case .curtain: ZenCurtain(text: text)
        case .desk: ZenDesk(text: text)
        case .spotlight: ZenSpotlight(text: text)
        case .bloom: ZenBloom(text: text)
        }
    }

    /// The frame each variant is mocked at: the panel is 390 wide, the rest are windows.
    var stageSize: CGSize {
        self == .bloom ? CGSize(width: 390, height: 660) : CGSize(width: 940, height: 640)
    }
}

enum ZenSample {
    static let text = """
    # Second brain, one file

    Capture has never been the problem. The problem is that everything I write down lands
    somewhere with a sidebar, a breadcrumb trail, and four ways to categorise it before the
    thought is even finished.

    ## What a note actually needs

    - a first line that becomes its title
    - a section, chosen later, not first
    - text that stays *text*

    > The tool should be quieter than the thought.

    When I am writing a long note the panel stops helping. The list, the search field, the
    section labels — all of it is chrome for finding notes, and I am not finding anything,
    I am writing. That is the whole case for a focus mode: same document, less room for
    everything that is not the document.
    """
}

// MARK: - Shared pieces

/// The writing column every variant shares: capped width, centred, real Markdown editor.
private struct ZenColumn: View {
    @Binding var text: String
    var width: CGFloat = 700
    var fontSize: CGFloat = 19
    var dims = false
    var typewriter = false
    var focusRequest: UUID

    @Environment(\.appFontTheme) private var fontTheme

    var body: some View {
        LiveMarkdownEditor(
            text: $text,
            focusRequest: focusRequest,
            fontTheme: fontTheme,
            fontSize: fontSize,
            inset: NSSize(width: 0, height: 34),
            dimsUnfocusedText: dims,
            typewriter: typewriter
        )
        .frame(maxWidth: width)
        .frame(maxWidth: .infinity)
    }
}

private struct ZenMeta: View {
    let text: String
    var section = "Inbox"

    private var words: Int {
        text.split { $0.isWhitespace || $0.isNewline }.count
    }

    var body: some View {
        HStack(spacing: 14) {
            Text(section.uppercased())
                .tracking(0.8)
            Text("\(words) words")
            Text("\(text.count) characters")
        }
        .font(.system(size: 10.5, weight: .medium))
        .foregroundStyle(.tertiary)
    }
}

private struct ZenKeyHint: View {
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

// MARK: - 1 · Curtain

/// Shipped as the app's focus mode. The lab renders the real `FocusEditorSurface` rather
/// than a copy of it, so the storybook cannot drift away from what ⇧⌘F actually opens.
struct ZenCurtain: View {
    @Binding var text: String
    @State private var sectionID = ZenCurtain.sections[0].id
    @State private var focusRequest = UUID()
    @State private var isCommandHeld = false
    @State private var flagsMonitor: Any?

    static let sections = [
        StashSection(name: "Inbox"),
        StashSection(name: "Reading"),
        StashSection(name: "Later"),
    ]

    var body: some View {
        FocusEditorSurface(
            markdown: $text,
            sectionID: $sectionID,
            sections: Self.sections,
            focusRequest: focusRequest,
            isCommandHeld: isCommandHeld,
            onExit: {},
            onSave: {}
        )
        .onAppear {
            flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
                isCommandHeld = event.modifierFlags.contains(.command)
                return event
            }
        }
        .onDisappear {
            if let flagsMonitor { NSEvent.removeMonitor(flagsMonitor) }
            flagsMonitor = nil
        }
    }
}

// MARK: - 2 · Desk

/// A resizable window you leave open. Because it persists, it keeps a permanent — but very
/// quiet — status line rather than hiding everything and making you hunt for state.
struct ZenDesk: View {
    @Binding var text: String
    @State private var focusRequest = UUID()
    @State private var section = "Inbox"

    var body: some View {
        ZStack {
            Color.clear
                .glassEffect(.regular, in: Rectangle())
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Empty drag region where the titlebar would be. Deliberately blank:
                // the window's identity is the text, not a title.
                Color.clear.frame(height: 28)

                ZenColumn(text: $text, width: 720, fontSize: 18, focusRequest: focusRequest)

                status
            }
        }
    }

    private var status: some View {
        HStack(spacing: 12) {
            Menu {
                ForEach(["Inbox", "Reading", "Later"], id: \.self) { name in
                    Button(name) { section = name }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(section.uppercased())
                        .tracking(0.8)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 7, weight: .semibold))
                }
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()

            ZenMeta(text: text)

            Spacer()

            HStack(spacing: 5) {
                Circle()
                    .fill(Color.accentColor.opacity(0.85))
                    .frame(width: 5, height: 5)
                Text("Saved")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.tertiary)
            }
            ZenKeyHint(keys: "⌘S", label: "save")
        }
        .padding(.horizontal, 18)
        .frame(height: 30)
        .background(alignment: .top) {
            Rectangle()
                .fill(.quaternary)
                .frame(height: 0.5)
        }
    }
}

// MARK: - 3 · Spotlight

/// The deepest setting: the caret stays parked at 42% of the window and every block but the
/// one it sits in fades back. Meant as a toggle inside Curtain or Desk, not a separate mode.
struct ZenSpotlight: View {
    @Binding var text: String
    @State private var focusRequest = UUID()

    var body: some View {
        ZStack {
            Color.clear
                .glassEffect(.regular, in: Rectangle())
                .ignoresSafeArea()
            Color.black.opacity(0.38)
                .ignoresSafeArea()

            ZenColumn(
                text: $text,
                width: 660,
                fontSize: 20,
                dims: true,
                typewriter: true,
                focusRequest: focusRequest
            )
            .mask(gradientMask)
        }
        .overlay(alignment: .leading) { caretRule }
        .overlay(alignment: .bottom) {
            ZenMeta(text: text)
                .padding(.bottom, 12)
        }
    }

    /// Text dissolves at the top and bottom edges instead of being clipped by them.
    private var gradientMask: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.13),
                .init(color: .black, location: 0.87),
                .init(color: .clear, location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// A single accent tick at the typewriter line — the only chrome in this variant.
    private var caretRule: some View {
        GeometryReader { proxy in
            Capsule()
                .fill(Color.accentColor.opacity(0.5))
                .frame(width: 2, height: 16)
                .position(x: 14, y: proxy.size.height * 0.42)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - 4 · Bloom

/// No overlay and no window: the composer at the bottom of the panel grows upward until it
/// is the panel. Keeps capture-and-write as one uninterrupted gesture at 390 points wide.
struct ZenBloom: View {
    @Binding var text: String
    @State private var focusRequest = UUID()

    var body: some View {
        ZStack {
            Color.clear
                .glassEffect(.regular, in: Rectangle())
                .ignoresSafeArea()

            // What the composer grew over, still faintly there.
            ghostList
                .opacity(0.16)
                .blur(radius: 2.5)
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                LiveMarkdownEditor(
                    text: $text,
                    focusRequest: focusRequest,
                    fontSize: 15,
                    inset: NSSize(width: 14, height: 14)
                )

                HStack(spacing: 8) {
                    ZenMeta(text: text)
                    Spacer()
                    Text("\u{23CE} SAVE")
                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                        .tracking(0.9)
                        .foregroundStyle(.tertiary)
                    Image(systemName: "arrow.up")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tint)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            }
            .glassEffect(
                Glass.regular.tint(Color.accentColor.opacity(0.08)),
                in: RoundedRectangle(cornerRadius: 13)
            )
            .overlay {
                // The composer's own focus ring, at the size of the panel.
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.accentColor.opacity(0.22), lineWidth: 5)
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.accentColor, lineWidth: 2)
                }
            }
            .padding(12)
        }
        .overlay(alignment: .top) {
            ZenKeyHint(keys: "⎋", label: "back to the list")
                .padding(.top, 2)
        }
    }

    private var ghostList: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("INBOX")
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.1)
            ForEach(0..<5, id: \.self) { row in
                RoundedRectangle(cornerRadius: 9)
                    .fill(.quaternary)
                    .frame(height: row.isMultiple(of: 2) ? 62 : 44)
            }
            Spacer()
        }
        .padding(14)
    }
}
