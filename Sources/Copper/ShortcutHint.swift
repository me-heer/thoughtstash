import SwiftUI

/// A small glass badge showing a shortcut's glyphs, looked up from `ShortcutMap` so
/// hints can never show a different key than the menu actually uses.
struct ShortcutHint: View {
    let notification: Notification.Name
    var label: String?

    var body: some View {
        if let display = ShortcutMap.display(for: notification) {
            HStack(spacing: 4) {
                if let label {
                    Text(label)
                }
                Text(display)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
            }
            .font(.system(size: 10, weight: .regular))
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 6))
        }
    }
}
