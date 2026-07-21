import Foundation

/// Environment-driven demo mode, used to pose the app for App Store screenshots.
///
/// Marketing captures are where most indie apps lose time and quality. Doing it by hand means
/// booting a simulator, tapping to the right screen, faking a purchase to see the Pro state,
/// and hoping the data looks good, then repeating all of it for every device size, and again
/// for every release when a string changes.
///
/// Instead the app can pose ITSELF: `scripts/screenshots.sh` launches the binary with these
/// variables set, so each shot is a deterministic, repeatable command. The Pro state comes from
/// a mock provider (never a real purchase), and the data comes from a seeded in-memory store
/// (never the user's real data, never CloudKit).
///
/// This is inert in production: nothing sets these variables on a device, and the App Store
/// build has no way to reach the branches. It is worth confirming that claim before every
/// submission though, because a demo mode that CAN be triggered by a user is a review rejection.
///
///   DEMO_MODE=1        turn the whole thing on
///   DEMO_TAB=settings  which tab to open
///   DEMO_PRO=1         show the unlocked state
enum DemoMode {
    private static let env = ProcessInfo.processInfo.environment

    /// True only when explicitly requested by a launch environment variable.
    static var isActive: Bool { env["DEMO_MODE"] == "1" }

    /// Which tab to open on launch. Nil means the app's default.
    static var tab: String? { env["DEMO_TAB"] }

    /// Whether to pose the unlocked Pro state. Backed by `MockEntitlementProvider`, so no
    /// StoreKit call happens and no real transaction exists.
    static var forcesPro: Bool { env["DEMO_PRO"] == "1" }

    /// Whether onboarding should be skipped, so captures land straight on real UI.
    static var skipsOnboarding: Bool { isActive }
}
