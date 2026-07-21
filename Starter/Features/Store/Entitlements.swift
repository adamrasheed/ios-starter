import Foundation

/// The paid-tier contract. Everything paid gates against `Entitlements.isPro`.
///
/// The actual "is this user Pro?" logic lives behind this protocol so the app can be built
/// and tested against `MockEntitlementProvider` long before any payment code exists — and so
/// the swap to the real thing is a single line in `RootView`. That sequencing matters more
/// than it looks: it lets you finish and demo every paid feature while App Store Connect
/// product setup, agreements and banking are still pending.
protocol EntitlementProvider: Sendable {
    func currentIsPro() async -> Bool

    /// Returns true if the purchase succeeded.
    func purchasePro() async throws -> Bool

    /// Returns true if a prior purchase was restored.
    func restore() async throws -> Bool

    /// Fresh Pro state pushed whenever a transaction arrives *outside* a direct purchase:
    /// a refund or revocation, an Ask-to-Buy approval, or a purchase made on another device.
    /// Observing this is what makes those cases apply without waiting for a relaunch.
    var isProUpdates: AsyncStream<Bool> { get }
}

/// Observable Pro state, injected into the SwiftUI environment by `RootView`.
///
/// One instance for the whole app. Features never talk to a provider directly; they read
/// `isPro` and call `purchasePro()` / `restore()` here, so entitlement state can never
/// disagree with itself across screens.
@MainActor
@Observable
final class Entitlements {
    private(set) var isPro = false

    private let provider: EntitlementProvider

    init(provider: EntitlementProvider = MockEntitlementProvider()) {
        self.provider = provider
    }

    func refresh() async {
        isPro = await provider.currentIsPro()
    }

    /// Initial state plus live updates, kept running for the app's lifetime by `RootView`'s
    /// `.task`. The `for await` loop is what applies refunds, Ask-to-Buy approvals and
    /// cross-device purchases the moment the provider surfaces them.
    func activate() async {
        await refresh()
        for await pro in provider.isProUpdates {
            isPro = pro
        }
    }

    func purchasePro() async throws {
        if try await provider.purchasePro() { isPro = true }
    }

    func restore() async throws {
        if try await provider.restore() { isPro = true }
    }
}

/// Development and preview stand-in.
///
/// Build paid features against this first. Set `isPro: true` to preview the unlocked state
/// end to end with no StoreKit involved, and `false` to check that every gate actually holds.
struct MockEntitlementProvider: EntitlementProvider {
    var isPro = false

    /// No out-of-band updates in the mock; finishes immediately so `activate()`'s loop ends.
    var isProUpdates: AsyncStream<Bool> { AsyncStream { $0.finish() } }

    func currentIsPro() async -> Bool { isPro }
    func purchasePro() async throws -> Bool { true }
    func restore() async throws -> Bool { isPro }
}
