import Testing
@testable import Starter

/// Tests for the paid-tier decision.
///
/// Note what makes these possible: `isProEntitled` takes a plain array of a small local struct
/// rather than reading `Transaction.currentEntitlements` itself. Only StoreKit can mint a real
/// `Transaction`, so a rule written directly against that type cannot be tested at all — you
/// would be left verifying your billing logic by hand, in a simulator, on the day you ship.
///
/// The general lesson, and the one worth carrying into every app: when a decision depends on a
/// type you cannot construct, shrink the input to one you can.
@Suite("Pro entitlement decision")
struct EntitlementDecisionTests {
    typealias Entitlement = StoreKitEntitlementProvider.Entitlement

    private let productID = "com.example.starter.pro"

    @Test("No entitlements means not Pro")
    func emptyIsNotPro() {
        #expect(StoreKitEntitlementProvider.isProEntitled(productID: productID, entitlements: []) == false)
    }

    @Test("A matching, un-revoked entitlement unlocks Pro")
    func matchingUnlocks() {
        let entitlements = [Entitlement(productID: productID, revocationDate: nil)]
        #expect(StoreKitEntitlementProvider.isProEntitled(productID: productID, entitlements: entitlements))
    }

    /// The refund case. Without the revocation check a refunded user keeps the feature forever,
    /// which is both a revenue leak and, at scale, the kind of thing that draws Apple's
    /// attention.
    @Test("A revoked entitlement does not unlock Pro")
    func revokedDoesNotUnlock() {
        let entitlements = [Entitlement(productID: productID, revocationDate: .now)]
        #expect(StoreKitEntitlementProvider.isProEntitled(productID: productID, entitlements: entitlements) == false)
    }

    /// Guards against the bug where any purchase in the app unlocks everything.
    @Test("An entitlement for a different product does not unlock Pro")
    func otherProductDoesNotUnlock() {
        let entitlements = [Entitlement(productID: "com.example.starter.tip", revocationDate: nil)]
        #expect(StoreKitEntitlementProvider.isProEntitled(productID: productID, entitlements: entitlements) == false)
    }

    @Test("A valid entitlement among revoked and unrelated ones still unlocks Pro")
    func mixedSetUnlocks() {
        let entitlements = [
            Entitlement(productID: "com.example.starter.other", revocationDate: nil),
            Entitlement(productID: productID, revocationDate: .now),
            Entitlement(productID: productID, revocationDate: nil),
        ]
        #expect(StoreKitEntitlementProvider.isProEntitled(productID: productID, entitlements: entitlements))
    }
}

/// Tests for the observable wrapper, driven by the mock provider.
@Suite("Entitlements observable")
@MainActor
struct EntitlementsTests {
    @Test("Starts locked")
    func startsLocked() {
        #expect(Entitlements(provider: MockEntitlementProvider(isPro: false)).isPro == false)
    }

    @Test("Refresh adopts the provider's state")
    func refreshAdoptsProviderState() async {
        let entitlements = Entitlements(provider: MockEntitlementProvider(isPro: true))
        await entitlements.refresh()
        #expect(entitlements.isPro)
    }

    @Test("A successful purchase unlocks Pro")
    func purchaseUnlocks() async throws {
        let entitlements = Entitlements(provider: MockEntitlementProvider(isPro: false))
        try await entitlements.purchasePro()
        #expect(entitlements.isPro)
    }

    /// Restore must not fabricate an unlock for someone who never bought.
    @Test("Restore with nothing to restore leaves Pro locked")
    func restoreWithoutPurchaseStaysLocked() async throws {
        let entitlements = Entitlements(provider: MockEntitlementProvider(isPro: false))
        try await entitlements.restore()
        #expect(entitlements.isPro == false)
    }

    @Test("Restore recovers a prior purchase")
    func restoreRecoversPurchase() async throws {
        let entitlements = Entitlements(provider: MockEntitlementProvider(isPro: true))
        try await entitlements.restore()
        #expect(entitlements.isPro)
    }
}
