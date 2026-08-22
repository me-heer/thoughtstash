import SwiftUI

/// Ambient accent glow for small/non-glass controls (buttons, menu triggers, hint
/// badges). Glass surfaces should prefer `Glass.regular.interactive()` instead —
/// don't stack both on the same element.
struct HoverGlow: ViewModifier {
    var color: Color = .accentColor
    var radius: CGFloat = 14
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: radius)
                    .fill(color.opacity(isHovering ? 0.22 : 0))
                    .blur(radius: radius)
            }
            .scaleEffect(isHovering ? 1.03 : 1)
            .animation(.easeOut(duration: 0.16), value: isHovering)
            .onHover { isHovering = $0 }
    }
}

extension View {
    func hoverGlow(color: Color = .accentColor, radius: CGFloat = 14) -> some View {
        modifier(HoverGlow(color: color, radius: radius))
    }
}
