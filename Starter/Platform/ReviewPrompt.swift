import StoreKit
import UIKit

/// Decides WHEN to ask for an App Store review.
///
/// Ratings move App Store conversion more than almost anything else you control, and Apple gives
/// you a hard budget: `requestReview` displays at most three times per user per 365 days, and the
/// system silently swallows every request past that. Spending one of those three on someone who
/// has opened the app once throws away a third of your annual ratings budget on a person with no
/// opinion yet.
///
/// So the ask is gated on evidence the person actually likes the app:
///   1. they have completed the core action several times, and
///   2. the app has been installed for a couple of days (excludes the curious first session), and
///   3. you have not already asked in this version.
///
/// The rule NOT encoded here, because only the call site knows it: never ask right after
/// something went wrong. Call `recordMilestone()` on success paths only.
///
/// Backed by `UserDefaults` directly rather than `@AppStorage`. `@AppStorage` is a
/// `DynamicProperty`: it only republishes inside a SwiftUI `View`, so in a plain class it
/// compiles, appears to work, and quietly fails to drive updates.
@MainActor
@Observable
final class ReviewPrompt {
    /// Milestones required before the first ask. Tune to your app: raise it for something used
    /// daily, lower it for a one-shot utility.
    private let milestoneThreshold: Int
    /// Days since first launch before any ask.
    private let minimumDaysInstalled: Int

    private let defaults: UserDefaults

    private enum Key {
        static let milestoneCount = "review.milestoneCount"
        static let firstLaunchAt = "review.firstLaunchAt"
        static let lastPromptedVersion = "review.lastPromptedVersion"
    }

    init(defaults: UserDefaults = .standard,
         milestoneThreshold: Int = 4,
         minimumDaysInstalled: Int = 2) {
        self.defaults = defaults
        self.milestoneThreshold = milestoneThreshold
        self.minimumDaysInstalled = minimumDaysInstalled
    }

    private(set) var milestoneCount: Int {
        get { defaults.integer(forKey: Key.milestoneCount) }
        set { defaults.set(newValue, forKey: Key.milestoneCount) }
    }

    private var firstLaunchAt: Double {
        get { defaults.double(forKey: Key.firstLaunchAt) }
        set { defaults.set(newValue, forKey: Key.firstLaunchAt) }
    }

    private var lastPromptedVersion: String {
        get { defaults.string(forKey: Key.lastPromptedVersion) ?? "" }
        set { defaults.set(newValue, forKey: Key.lastPromptedVersion) }
    }

    /// Call once at launch.
    func registerLaunch(now: Date = .now) {
        if firstLaunchAt == 0 {
            firstLaunchAt = now.timeIntervalSince1970
        }
    }

    /// Call when the user successfully completes the app's core action, the thing they
    /// downloaded it for. Not on launch, and never on an error path.
    func recordMilestone() {
        milestoneCount += 1
    }

    /// The pure decision, so it can be tested without a window scene or a live StoreKit call.
    func hasEarnedPrompt(currentVersion: String = AppInfo.version, now: Date = .now) -> Bool {
        guard milestoneCount >= milestoneThreshold else { return false }
        guard lastPromptedVersion != currentVersion else { return false }
        guard firstLaunchAt > 0 else { return false }
        let daysInstalled = (now.timeIntervalSince1970 - firstLaunchAt) / 86_400
        return daysInstalled >= Double(minimumDaysInstalled)
    }

    /// Ask if, and only if, the prompt has been earned. Safe to call often; it is a no-op
    /// until the conditions are met.
    func requestIfEarned(in scene: UIWindowScene?) {
        guard let scene, hasEarnedPrompt() else { return }
        lastPromptedVersion = AppInfo.version
        AppLog.app.info("Requesting App Store review after \(self.milestoneCount) milestones")
        AppStore.requestReview(in: scene)
    }
}
