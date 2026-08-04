import Foundation
import Testing
@testable import Starter

/// Locates the test bundle, which is where `Starter.storekit` is copied (see `project.yml`: the
/// config is a resource of the TEST target, never of the app).
private final class BundleToken {}

/// The shape of a StoreKit configuration file, reduced to the fields worth asserting on.
private struct StoreKitConfiguration: Decodable {
    struct Product: Decodable {
        let displayPrice: String
        let productID: String
        let type: String
        let familyShareable: Bool
    }

    /// Decodes any object without inspecting it: enough to count the entries.
    struct Entry: Decodable {}

    enum LoadError: Error {
        /// `Starter.storekit` is not in the test bundle. Check `project.yml`: the test target
        /// copies it in as a resource.
        case fileMissing
    }

    let products: [Product]
    let subscriptionGroups: [Entry]
    let nonRenewingSubscriptions: [Entry]

    static func load() throws -> StoreKitConfiguration {
        let bundle = Bundle(for: BundleToken.self)
        guard let url = bundle.url(forResource: "Starter", withExtension: "storekit") else {
            throw LoadError.fileMissing
        }
        return try JSONDecoder().decode(StoreKitConfiguration.self, from: Data(contentsOf: url))
    }
}

/// Product configuration.
///
/// These exist because the failure they catch is invisible. If the id in `Starter.storekit` drifts
/// from `StoreProduct.pro`, `Product.products(for:)` returns an empty array, the paywall shows no
/// price and the buy button does nothing: no crash, no error, no log anyone reads. Nobody finds
/// out until a user opens the paywall, which is the exact moment you were about to be paid.
///
/// What these do NOT prove: that the product exists in App Store Connect, or that a purchase
/// works. `SKTestSession` cannot activate under headless `xcodebuild`, so the real purchase and
/// restore flow is device-only. See `docs/ship-checklist.md`.
@Suite("Paywall product configuration")
struct PaywallProductConfigurationTests {
    @Test("The .storekit file defines exactly one product")
    func exactlyOneProduct() throws {
        #expect(try StoreKitConfiguration.load().products.count == 1)
    }

    @Test("The product id exactly matches StoreProduct.pro")
    func productIDMatchesCode() throws {
        let configuration = try StoreKitConfiguration.load()
        let product = try #require(configuration.products.first)
        #expect(product.productID == StoreProduct.pro)
    }

    @Test("The unlock is a non-consumable")
    func unlockIsNonConsumable() throws {
        let configuration = try StoreKitConfiguration.load()
        let product = try #require(configuration.products.first)
        #expect(product.type == "NonConsumable")
    }

    /// The business model, asserted. A subscription is the single change most likely to be made
    /// casually here, and it changes ADR-004, the App Store listing, and probably justifies
    /// RevenueCat. If you genuinely want one, delete this test deliberately.
    @Test("There are no subscriptions of any kind")
    func noSubscriptions() throws {
        let configuration = try StoreKitConfiguration.load()
        #expect(configuration.subscriptionGroups.isEmpty)
        #expect(configuration.nonRenewingSubscriptions.isEmpty)
    }

    /// Family Sharing turns one purchase into up to six. That may be the right call, but it
    /// should be a decision someone made, not a default that flipped.
    @Test("Family Sharing is off")
    func familySharingIsOff() throws {
        let configuration = try StoreKitConfiguration.load()
        let product = try #require(configuration.products.first)
        #expect(product.familyShareable == false)
    }
}

/// Paywall copy.
///
/// Not style policing. Each of these encodes a rule that costs real money to break. See the
/// doc comment on `PaywallCopy` for the one they exist to serve: a perk goes on the paywall in
/// the same commit that ships the feature, never before.
@Suite("Paywall copy")
struct PaywallCopyTests {
    /// Every user-facing string on the paywall. Add to this when you add copy, or the rules below
    /// silently stop covering it.
    ///
    /// `buyTitle(price:)` is sampled with a placeholder rather than a real price, so the
    /// hardcoded-price rule tests the template around the price and not the price itself.
    private var allCopy: [String] {
        [PaywallCopy.headline,
         PaywallCopy.subhead,
         PaywallCopy.buyTitle(price: "<price>"),
         PaywallCopy.buyFallbackTitle,
         PaywallCopy.restoreTitle,
         PaywallCopy.priceUnavailable,
         PaywallCopy.restoreFoundNothing,
         PaywallCopy.closeTitle,
         PaywallCopy.errorTitle,
         PaywallCopy.errorDismissTitle]
            + PaywallCopy.perks.flatMap { [$0.title, $0.detail] }
    }

    /// The buy title must actually show the price it was handed. A template that drops it leaves
    /// the button reading "Unlock for" with no number, which no test would otherwise catch.
    @Test("The buy title includes the price it is given")
    func buyTitleIncludesPrice() {
        #expect(PaywallCopy.buyTitle(price: "$4.99").contains("$4.99"))
    }

    @Test("Every perk has an icon, a title and a detail")
    func perksAreComplete() {
        #expect(PaywallCopy.perks.isEmpty == false)
        for perk in PaywallCopy.perks {
            #expect(perk.icon.isEmpty == false)
            #expect(perk.title.isEmpty == false)
            #expect(perk.detail.isEmpty == false)
        }
    }

    /// The reconciliation gate, in the only form a unit test can enforce: you cannot claim
    /// something on the paywall without naming the code that delivers it.
    ///
    /// This does not prove the named code exists, and it is not meant to. It makes the claim and
    /// its justification travel together, so the pre-submission grep of `Features/` is a lookup
    /// rather than an investigation. Two shipped apps from this template sold features that were
    /// not there; both would have been caught by having to fill this field in honestly.
    @Test("Every perk names the code that delivers it")
    func perksCiteTheirImplementation() {
        for perk in PaywallCopy.perks {
            // Built into a `let` first: #expect re-emits its comment argument as a `Comment`,
            // not a `String`, so `"a" + "b"` does not compile there.
            let message = "\"\(perk.title)\" has no evidence. Name the type or view that "
                + "delivers it, or take the perk off the paywall."
            #expect(perk.evidence.isEmpty == false, "\(message)")
        }
    }

    /// Prices differ by storefront and change with tax rules. The only correct source is
    /// `Product.displayPrice` at runtime.
    @Test("No copy hardcodes a price")
    func noHardcodedPrice() {
        // Compared case-insensitively: the symbols have no case, but the currency codes do, and
        // "usd" is as much a hardcoded marker as "USD".
        let priceMarkers = ["$", "€", "£", "¥", "usd", "eur", "gbp"]
        for text in allCopy {
            let lowercased = text.lowercased()
            for marker in priceMarkers {
                #expect(lowercased.contains(marker) == false,
                        "\"\(text)\" contains \(marker); the price must come from StoreKit.")
            }
        }
    }

    @Test("No copy promises a subscription, a trial or an account")
    func noRecurringOrAccountLanguage() {
        let banned = ["per month", "per year", "monthly", "yearly", "annual", "/mo",
                      "trial", "auto-renew", "renews", "sign up", "sign in", "log in",
                      "create an account"]
        for text in allCopy {
            let lowercased = text.lowercased()
            for phrase in banned {
                #expect(lowercased.contains(phrase) == false,
                        "\"\(text)\" contains \"\(phrase)\".")
            }
        }
    }

    /// House style, and it reaches production because nothing else checks. Shipped apps from this
    /// template have put em dashes into in-app strings and into a published support page.
    @Test("No copy contains an em dash")
    func noEmDashes() {
        for text in allCopy {
            #expect(text.contains("\u{2014}") == false, "\"\(text)\" contains an em dash.")
        }
    }

    /// Apple requires a restore path for a non-consumable and reviewers look for this exact
    /// wording. Renaming it to something clever is a routine rejection.
    @Test("Restore is offered by its expected name")
    func restoreIsNamedConventionally() {
        #expect(PaywallCopy.restoreTitle == "Restore Purchases")
    }

    /// The one-time purchase is the reason people buy rather than bounce, so it is stated where
    /// it cannot be missed. Delete this if you switch to a subscription.
    @Test("The subhead states that there is no subscription")
    func subheadRulesOutASubscription() {
        #expect(PaywallCopy.subhead.lowercased().contains("no subscription"))
    }

    /// Guard against a title that truncates into nonsense at accessibility text sizes. The detail
    /// line can wrap; a headline-weight title that wraps three times cannot be skimmed.
    @Test("Perk titles stay short enough to survive large text")
    func perkTitlesAreShort() {
        for perk in PaywallCopy.perks {
            #expect(perk.title.count <= 60, "\"\(perk.title)\" is \(perk.title.count) characters.")
        }
    }

    // ENABLE THIS if your app's free tier is deliberately complete: a calculator that is correct
    // for everyone, a reader that opens every file. Selling "unlock every feature" when the core
    // function is already free is the same 2.3.1 rejection from the other direction, and it is
    // the pattern that fills competitors' one-star reviews. The default perks above are written
    // for the opposite case, so this test ships disabled.
    //
    // @Test("No copy claims the app's features are locked as a whole")
    // func noBlanketUnlockClaims() {
    //     let banned = ["every feature", "all features", "everything unlocked", "full access",
    //                   "unlock everything"]
    //     for text in allCopy {
    //         let lowercased = text.lowercased()
    //         for phrase in banned {
    //             #expect(lowercased.contains(phrase) == false,
    //                     "\"\(text)\" contains \"\(phrase)\".")
    //         }
    //     }
    // }
}
