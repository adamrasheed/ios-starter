import Foundation

/// Analytics behind a protocol, with a console implementation as the default.
///
/// Why a protocol and not just a PostHog/Firebase/Mixpanel call: vendors get swapped, and an
/// SDK sprinkled through 40 view files is a week of work to remove. More usefully, a protocol
/// means tests can assert "this flow logs `paywall_shown` exactly once" without a network call,
/// and previews and simulator runs never pollute production numbers.
///
/// To wire a real vendor, write one conformance and change the single assignment in
/// `AppMain`. Nothing else in the app changes.
protocol AnalyticsClient: Sendable {
    func track(_ event: AnalyticsEvent)
    func identify(userID: String, traits: [String: String])
}

/// Events as a closed enum, not free-form strings.
///
/// String event names rot: `"paywall_shown"` in one file and `"paywall_show"` in another
/// silently splits a funnel in two, and you find out weeks later while reading a chart that
/// makes no sense. An enum makes that a compile error, and gives you the full event catalogue
/// in one readable place.
enum AnalyticsEvent {
    case appLaunched
    case onboardingCompleted
    case paywallShown(source: String)
    case purchaseStarted
    case purchaseCompleted
    case purchaseFailed(reason: String)
    case purchaseRestored
    /// Escape hatch for app-specific events. Prefer adding a case above.
    case custom(name: String, properties: [String: String])

    var name: String {
        switch self {
        case .appLaunched: return "app_launched"
        case .onboardingCompleted: return "onboarding_completed"
        case .paywallShown: return "paywall_shown"
        case .purchaseStarted: return "purchase_started"
        case .purchaseCompleted: return "purchase_completed"
        case .purchaseFailed: return "purchase_failed"
        case .purchaseRestored: return "purchase_restored"
        case .custom(let name, _): return name
        }
    }

    var properties: [String: String] {
        switch self {
        case .paywallShown(let source): return ["source": source]
        case .purchaseFailed(let reason): return ["reason": reason]
        case .custom(_, let properties): return properties
        default: return [:]
        }
    }
}

/// Default implementation: writes to the unified log and goes nowhere else.
///
/// Shipping with this is a perfectly reasonable choice for v1. Analytics you never read is
/// worse than none: it costs a dependency, a privacy-manifest entry, and an App Store
/// tracking disclosure in exchange for numbers nobody looks at.
struct ConsoleAnalyticsClient: AnalyticsClient {
    func track(_ event: AnalyticsEvent) {
        AppLog.analytics.debug("event=\(event.name, privacy: .public) props=\(event.properties.description, privacy: .public)")
    }

    func identify(userID: String, traits: [String: String]) {
        AppLog.analytics.debug("identify=\(userID, privacy: .private(mask: .hash))")
    }
}

/// No-op implementation for tests and previews.
struct NoopAnalyticsClient: AnalyticsClient {
    func track(_ event: AnalyticsEvent) {}
    func identify(userID: String, traits: [String: String]) {}
}
