import Foundation

/// Every user-facing string on the paywall, in one place.
///
/// This exists so the copy can be tested. That sounds like style policing and is not: the rules in
/// `PaywallCopyTests` each encode a mistake that costs real money.
///
/// **The rule this type exists to enforce: a perk goes on the paywall in the same commit that
/// ships the feature, never before.** App Review tests in-app purchases, so selling something the
/// binary does not do is a guideline 2.3.1 rejection. It has happened twice on shipped apps from
/// this template: one sold two features that had no implementing code at all, and one sold two
/// *free* features as Pro unlocks and needed a resubmission.
///
/// A claim about what Pro includes lives in **five** places and they must move together:
///   1. `PaywallCopy.perks` (here)
///   2. The App Store description
///   3. The in-app-purchase description in App Store Connect
///   4. The release notes
///   5. The support page
///
/// Before every submission, grep `Features/` for the code behind each perk. `evidence` below is
/// where you record what you found, so the next person does not have to re-derive it.
enum PaywallCopy {
    struct Perk: Identifiable {
        let id = UUID()
        /// SF Symbol name.
        let icon: String
        /// Short enough to survive accessibility text sizes without wrapping three times.
        let title: String
        let detail: String
        /// The type, view or symbol in this app that actually delivers this perk.
        ///
        /// Not shown to the user. It is here so the claim cannot be written without someone
        /// naming the code that backs it, and so the pre-submission check is a lookup rather
        /// than an archaeology exercise. A perk you cannot fill this in for does not ship.
        let evidence: String
    }

    static let headline = "\(AppInfo.displayName) Pro"
    static let subhead = "A one-time unlock. No subscription."

    /// The buy button once StoreKit has returned a price.
    ///
    /// Takes the price rather than embedding one: prices differ by storefront and change with tax
    /// rules, so the only correct source is `Product.displayPrice` at runtime.
    static func buyTitle(price: String) -> String { "Unlock for \(price)" }

    /// Shown when StoreKit has not returned a price yet.
    static let buyFallbackTitle = "Unlock Pro"

    static let closeTitle = "Close"
    static let errorTitle = "Something went wrong"
    static let errorDismissTitle = "OK"

    /// Apple requires a restore path for a non-consumable, and reviewers look for this exact
    /// wording. Renaming it to something clever is a routine rejection.
    static let restoreTitle = "Restore Purchases"

    static let priceUnavailable =
        "Pricing couldn't be loaded right now. You can still restore a previous purchase."
    static let restoreFoundNothing = "No previous purchase was found for your Apple ID."

    /// REPLACE with what your Pro tier actually unlocks. Write benefits, not features: what the
    /// user can now do, in their words. Use the `copy-mentor` skill; this copy does more revenue
    /// work than any code on the screen.
    ///
    /// If your app's free tier is deliberately complete (a calculator that is correct for
    /// everyone, say) then delete the blanket "everything unlocked" perk below. Claiming the
    /// whole app is locked when it is not is the same rejection from the other direction, and
    /// `PaywallCopyTests` has a commented-out test to enforce that once you decide.
    static let perks: [Perk] = [
        Perk(icon: "wand.and.stars",
             title: "Everything unlocked",
             detail: "Full access to every feature, forever.",
             evidence: "ProGate.swift, applied at every gated call site"),
        Perk(icon: "icloud",
             title: "On all your devices",
             detail: "One purchase covers every device on your Apple ID.",
             evidence: "StoreKitEntitlementProvider: derived from Transaction.currentEntitlements"),
        Perk(icon: "heart",
             title: "Support development",
             detail: "A one-time purchase from an independent developer.",
             evidence: "Business model, not a feature. Safe: it promises nothing the app must do"),
    ]
}
