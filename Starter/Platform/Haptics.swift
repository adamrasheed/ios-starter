import UIKit

/// Haptic feedback, in one place so the app's physical vocabulary stays consistent.
///
/// Haptics are the cheapest delight in iOS and the easiest to overdo. The rule that holds up:
/// fire on events the user CAUSED and cares about the outcome of. A haptic on every tap becomes
/// noise within a minute, and users turn the feature off at the system level, taking your
/// meaningful ones with it.
///
/// `prepare()` before each trigger is not ceremony: it warms the Taptic Engine so the tap lands
/// with the action instead of a beat behind it, which is the difference between feeling
/// responsive and feeling broken.
@MainActor
enum Haptics {
    /// A task the user asked for finished correctly.
    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    /// A task failed. Pair with a visible message — never let a buzz be the only error report,
    /// because a user with haptics disabled then gets no feedback at all.
    static func failure() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
    }

    /// A warning or a rejected input, e.g. hitting a validation limit.
    static func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }

    /// A selection changed: picker moved, segment switched, item snapped into place.
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    /// A physical-feeling impact, e.g. a card landing or a toggle committing.
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
}
