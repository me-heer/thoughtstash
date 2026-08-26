import AppKit
import SwiftUI

/// A storybook for the distraction-free variants in `ZenMode`. Launch it with
/// `swift run ThoughtStash --zen-lab` (or `THOUGHTSTASH_ZEN_LAB=1`); it replaces the panel
/// for that run and never touches the notes file. ⌘1–⌘4 switch variants.
struct ZenLab: View {
    /// `THOUGHTSTASH_ZEN_VARIANT=desk` opens straight onto one variant, which is how the
    /// screenshots in docs/focus-mode-iterations.md are taken.
    @State private var variant: ZenVariant = ProcessInfo.processInfo.environment["THOUGHTSTASH_ZEN_VARIANT"]
        .flatMap(ZenVariant.init(rawValue:)) ?? .curtain
    @State private var drafts: [ZenVariant: String] = Dictionary(
        uniqueKeysWithValues: ZenVariant.allCases.map { ($0, ZenSample.text) }
    )
    @State private var keyMonitor: Any?

    var body: some View {
        HStack(spacing: 0) {
            rail
            stage
        }
        .frame(minWidth: 1180, minHeight: 820)
        .background(backdrop)
        .onAppear { installKeyMonitor() }
        .onDisappear {
            if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
            keyMonitor = nil
        }
    }

    // MARK: Storybook chrome (not part of any design)

    private var rail: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Focus mode")
                    .font(.system(size: 17, weight: .semibold))
                Text("Four iterations · ⌘1–⌘4")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18)
            .padding(.top, 26)
            .padding(.bottom, 18)

            ForEach(ZenVariant.allCases) { option in
                Button { variant = option } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("\(option.index)")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(option == variant ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.tertiary))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(option.title)
                                .font(.system(size: 13, weight: .medium))
                            Text(option.tagline)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 9)
                    .padding(.horizontal, 12)
                    .background {
                        RoundedRectangle(cornerRadius: 9)
                            .fill(option == variant ? Color.accentColor.opacity(0.12) : .clear)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
            }

            Divider()
                .padding(.horizontal, 18)
                .padding(.vertical, 20)

            VStack(alignment: .leading, spacing: 14) {
                note("Enter", variant.entry)
                note("Exit", variant.exit)
                note("What it costs", variant.cost)
            }
            .padding(.horizontal, 18)

            Spacer()

            Text("The editor in each frame is the real LiveMarkdownEditor — type in it.")
                .font(.system(size: 10.5))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(18)
        }
        .frame(width: 290)
        .background(.ultraThinMaterial)
        .overlay(alignment: .trailing) {
            Rectangle().fill(.quaternary).frame(width: 0.5)
        }
    }

    private func note(_ label: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1)
                .foregroundStyle(.tertiary)
            Text(body)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var stage: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 0)

            variant.view(text: binding(for: variant))
                .frame(width: variant.stageSize.width, height: variant.stageSize.height)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.14), lineWidth: 0.5)
                }
                .shadow(color: .black.opacity(0.45), radius: 34, y: 16)
                .id(variant)

            Text("\(variant.index) · \(variant.title) — \(variant.tagline)")
                .font(.system(size: 11.5))
                .foregroundStyle(.white.opacity(0.65))

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(28)
    }

    /// Stands in for a desktop so the Liquid Glass surfaces have something to sample.
    private var backdrop: some View {
        LinearGradient(
            colors: [
                Color(red: 0.10, green: 0.11, blue: 0.16),
                Color(red: 0.20, green: 0.15, blue: 0.26),
                Color(red: 0.09, green: 0.14, blue: 0.18),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            RadialGradient(
                colors: [Color.orange.opacity(0.16), .clear],
                center: .init(x: 0.72, y: 0.18),
                startRadius: 0,
                endRadius: 620
            )
        }
        .ignoresSafeArea()
    }

    private func binding(for variant: ZenVariant) -> Binding<String> {
        Binding(
            get: { drafts[variant] ?? "" },
            set: { drafts[variant] = $0 }
        )
    }

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // ⌘-prefixed so plain digits still reach the editor being demoed.
            guard event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
                  let characters = event.charactersIgnoringModifiers,
                  let number = Int(characters),
                  (1...ZenVariant.allCases.count).contains(number) else { return event }
            variant = ZenVariant.allCases[number - 1]
            return nil
        }
    }
}

@MainActor
final class ZenLabController: NSWindowController {
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1320, height: 880),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Focus Mode · Zen Lab"
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = NSHostingView(rootView: ZenLab())
        self.init(window: window)
    }
}
