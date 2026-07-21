import SwiftUI

// Design tokens.
//
// The point of this file is that a screen should never contain a raw number or a raw colour.
// When every view spells its own `.padding(17)` and `.foregroundStyle(.gray)`, the app drifts
// into looking almost-consistent, which reads as cheap in a way users feel but cannot name,
// and a redesign becomes a find-and-replace across every file instead of an edit to this one.
//
// Keep this small. Tokens earn their place by being used in three or more places; a one-off
// value belongs in the view that uses it.

// MARK: - Spacing

/// A 4pt scale. Named rather than numeric so intent survives a redesign: `Spacing.l` still
/// means "generous" after you change what generous is worth.
enum Spacing {
    /// 4pt — hairline separation inside a control.
    static let xs: CGFloat = 4
    /// 8pt — between tightly related elements.
    static let s: CGFloat = 8
    /// 12pt — default gap inside a group.
    static let m: CGFloat = 12
    /// 16pt — standard screen edge inset.
    static let l: CGFloat = 16
    /// 24pt — between distinct sections.
    static let xl: CGFloat = 24
    /// 32pt — around a screen's hero element.
    static let xxl: CGFloat = 32
}

// MARK: - Radius

enum Radius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 20
}

// MARK: - Colour

/// Semantic colour roles.
///
/// These deliberately resolve to SYSTEM colours rather than hex literals. System colours adapt
/// to light and dark mode, to increased-contrast and reduced-transparency accessibility
/// settings, and to whatever Apple changes next — all for free. Hardcoding `Color(hex: "#1C1C1E")`
/// buys you a dark mode that is subtly wrong the first time a user turns on Increase Contrast.
///
/// Override individual roles with an asset-catalog colour set when the brand genuinely needs it,
/// and change them HERE so every screen moves together.
extension ShapeStyle where Self == Color {
    /// The brand colour. Backed by the `AccentColor` asset — edit it there, once.
    static var brand: Color { Color.accentColor }

    /// Primary reading text.
    static var textPrimary: Color { Color.primary }

    /// Supporting text: subtitles, captions, metadata.
    static var textSecondary: Color { Color.secondary }

    /// De-emphasised text and decorative glyphs.
    static var textTertiary: Color { Color(uiColor: .tertiaryLabel) }

    /// The base background of a screen.
    static var surface: Color { Color(uiColor: .systemBackground) }

    /// A card or grouped row sitting on top of `surface`.
    static var surfaceElevated: Color { Color(uiColor: .secondarySystemBackground) }

    /// Hairline dividers and control borders.
    static var separator: Color { Color(uiColor: .separator) }
}

// MARK: - Typography

/// Named text roles.
///
/// Every one is built from a Dynamic Type text style, so the whole app scales when a user
/// raises their text size. Using `.system(size: 17)` instead freezes your app at one size and
/// makes it unusable for anyone who needs larger text — which is a large minority of people,
/// and an App Store review risk on top of that.
enum AppFont {
    /// Screen hero. One per screen at most.
    static let display = Font.largeTitle.bold()
    /// Section heading.
    static let title = Font.title3.weight(.semibold)
    /// Emphasised row label.
    static let headline = Font.headline
    /// Default reading text.
    static let body = Font.body
    /// Supporting text under a body line.
    static let caption = Font.subheadline
    /// Legal text, timestamps, footnotes.
    static let footnote = Font.footnote
}

// MARK: - Motion

/// Shared animation curves, so transitions across the app feel like one product.
///
/// Note `reduceMotion`: a spring that delights most users can cause genuine nausea for people
/// with vestibular disorders, and iOS exposes that preference precisely so you can respect it.
enum Motion {
    static let quick = Animation.snappy(duration: 0.2)
    static let standard = Animation.snappy(duration: 0.32)
    static let gentle = Animation.smooth(duration: 0.5)

    /// Returns `nil` when the user has asked for reduced motion, which disables the animation
    /// at the call site: `withAnimation(Motion.respecting(.standard, reduceMotion)) { ... }`
    static func respecting(_ animation: Animation, _ reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : animation
    }
}
