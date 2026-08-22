import SwiftUI

/// "Stamp" save feedback for the quick composer.
///
/// Saving with Return should read as a mechanical key press rather than a
/// flourish: the composer depresses, a ring ripples out from the caret, and the
/// new card drops in from above on a spring. Every part is driven off a
/// monotonically increasing save counter, so a burst of saves restarts the
/// effect cleanly instead of queueing animations behind each other.
///
/// Under Reduce Motion the save still confirms itself — the composer flashes its
/// accent once and the card cross-fades in — because a save with no feedback at
/// all is worse than a quiet one. Only the travelling parts are dropped.
enum Stamp {
    static let pressDuration = 0.09
    static let pressReturn = 0.34
    static let pressScale: CGFloat = 0.972
    static let ringDuration = 0.62
    static let ringStartDiameter: CGFloat = 26
    static let ringEndDiameter: CGFloat = 286
    static let flashDuration = 0.42

    static let cardDrop = Animation.spring(response: 0.32, dampingFraction: 0.62)
    static let cardFade = Animation.easeOut(duration: 0.2)
}

/// Depresses the composer like a keycap on each save.
struct StampPress: ViewModifier {
    let trigger: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content.keyframeAnimator(initialValue: CGFloat(1), trigger: trigger) { view, scale in
                view.scaleEffect(scale)
            } keyframes: { _ in
                KeyframeTrack {
                    CubicKeyframe(Stamp.pressScale, duration: Stamp.pressDuration)
                    SpringKeyframe(1, duration: Stamp.pressReturn, spring: .bouncy)
                }
            }
        }
    }
}

/// Save confirmation drawn inside the composer: a ring expanding from the caret,
/// or — under Reduce Motion — a single stationary accent flash.
struct StampRipple: View {
    let trigger: Int
    /// Caret-ish origin in the composer's own coordinate space.
    var origin: CGPoint = CGPoint(x: 22, y: 26)
    var cornerRadius: CGFloat = 12

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.accentColor)
                    .keyframeAnimator(initialValue: CGFloat(1), trigger: trigger) { view, progress in
                        view.opacity(0.28 * Double(1 - progress))
                    } keyframes: { _ in
                        KeyframeTrack {
                            MoveKeyframe(0)
                            CubicKeyframe(1, duration: Stamp.flashDuration)
                        }
                    }
            } else {
                // The frame grows rather than the view scaling, so the ring stays
                // a hairline instead of thickening into a wash.
                Circle()
                    .stroke(Color.accentColor, lineWidth: 1.5)
                    .keyframeAnimator(initialValue: CGFloat(1), trigger: trigger) { view, progress in
                        let diameter = Stamp.ringStartDiameter
                            + progress * (Stamp.ringEndDiameter - Stamp.ringStartDiameter)
                        view
                            .frame(width: diameter, height: diameter)
                            .opacity(0.9 * Double(1 - progress))
                            .position(origin)
                    } keyframes: { _ in
                        KeyframeTrack {
                            MoveKeyframe(0)
                            CubicKeyframe(1, duration: Stamp.ringDuration)
                        }
                    }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Drop-from-above used for note cards arriving in the list.
private struct StampDrop: ViewModifier {
    let offset: CGFloat
    let scale: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .offset(y: offset)
            .scaleEffect(scale)
            .opacity(opacity)
    }
}

extension AnyTransition {
    static var stampDrop: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: StampDrop(offset: -14, scale: 0.96, opacity: 0),
                identity: StampDrop(offset: 0, scale: 1, opacity: 1)
            ),
            removal: .opacity
        )
    }
}

extension View {
    func stampPress(trigger: Int) -> some View {
        modifier(StampPress(trigger: trigger))
    }
}
