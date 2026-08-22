import AppKit
import SwiftUI

/// The three typefaces the whole app can be rendered in, Notion-style. All three ship
/// with macOS and share optical sizing and metrics with the system UI, so switching
/// between them never drags in a download or shifts layout unpredictably:
/// SF Pro (default), New York (serif), SF Mono (monospace).
enum AppFontTheme: String, Codable, CaseIterable, Identifiable {
    case sans
    case serif
    case mono

    var id: Self { self }

    var title: String {
        switch self {
        case .sans: return "Default"
        case .serif: return "Serif"
        case .mono: return "Mono"
        }
    }

    /// The typeface name, for the settings picker and the switch confirmation.
    var faceName: String {
        switch self {
        case .sans: return "SF Pro"
        case .serif: return "New York"
        case .mono: return "SF Mono"
        }
    }

    var design: Font.Design {
        switch self {
        case .sans: return .default
        case .serif: return .serif
        case .mono: return .monospaced
        }
    }

    var systemDesign: NSFontDescriptor.SystemDesign {
        switch self {
        case .sans: return .default
        case .serif: return .serif
        case .mono: return .monospaced
        }
    }

    var next: AppFontTheme {
        let all = Self.allCases
        let index = all.firstIndex(of: self) ?? 0
        return all[(index + 1) % all.count]
    }

    /// The AppKit counterpart of `design`, for the two NSTextView-backed editors.
    func nsFont(size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        let base = NSFont.systemFont(ofSize: size, weight: weight)
        guard self != .sans,
              let descriptor = base.fontDescriptor.withDesign(systemDesign),
              let font = NSFont(descriptor: descriptor, size: size) else { return base }
        return font
    }
}

private struct AppFontThemeKey: EnvironmentKey {
    static let defaultValue: AppFontTheme = .sans
}

extension EnvironmentValues {
    /// Read by the NSTextView-backed editors, which can't pick up `.fontDesign`.
    var appFontTheme: AppFontTheme {
        get { self[AppFontThemeKey.self] }
        set { self[AppFontThemeKey.self] = newValue }
    }
}

extension View {
    /// Applies the theme to SwiftUI text (`.fontDesign`) and publishes it for the
    /// AppKit editors in one step. Sheets inherit it from the presenting view.
    func appFontTheme(_ theme: AppFontTheme) -> some View {
        environment(\.appFontTheme, theme)
            .fontDesign(theme.design)
    }
}
