import AppKit

/// The menu-bar counterpart of the app icon: the front note card, solid, under the
/// one thing you would actually see of the card behind it — its tilted top edge.
///
/// Drawn rather than shipped as an asset so it stays a template image, which is what
/// lets macOS invert it for light and dark menu bars. Two cards in outline collide at
/// 17 points; reducing the back card to an edge keeps two distinct weights with no
/// overlap to resolve.
enum StatusItemGlyph {
    static func image(pointSize: CGFloat = 17) -> NSImage {
        let image = NSImage(size: NSSize(width: pointSize, height: pointSize), flipped: false) { rect in
            let unit = rect.width / 100

            // Back card, reduced to its top edge and tilted the way the deck fans.
            let edge = NSBezierPath()
            edge.move(to: NSPoint(x: 21 * unit, y: 72 * unit))
            edge.line(to: NSPoint(x: 69 * unit, y: 78 * unit))
            edge.lineWidth = 7 * unit
            edge.lineCapStyle = .round
            NSColor.black.withAlphaComponent(0.45).setStroke()
            edge.stroke()

            // Front card.
            let card = NSBezierPath(
                roundedRect: NSRect(x: 17 * unit, y: 23 * unit, width: 66 * unit, height: 42 * unit),
                xRadius: 10 * unit,
                yRadius: 10 * unit
            )
            NSColor.black.setFill()
            card.fill()

            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Thought Stash"
        return image
    }
}
