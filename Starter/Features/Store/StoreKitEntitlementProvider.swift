import Foundation
import StoreKit

/// Identifiers for this app's in-app purchases.
enum StoreProduct {
    /// The one-time, non-consumable Pro unlock.
    ///
    /// This string must match three places or purchases silently fail to unlock anything:
    /// the `productID` in `Starter.storekit`, the product you create in App Store Connect,
    /// and here. Namespace it under the app's bundle id.
    static let pro = "com.example.starter.pro"
}

/// Errors surfaced from the StoreKit layer to the paywall.
enum StoreError: LocalizedError {
    case productNotFound
    case failedVerification

    var errorDescription: String? {
        switch self {
        case .productNotFound:
            return "This purchase could not be loaded from the App Store. Please try again."
        case .failedVerification:
            return "Your purchase could not be verified by the App Store."
        }
    }
}

/// Real StoreKit 2 implementation of `EntitlementProvider`, for a single non-consumable unlock.
///
/// `isPro` is derived purely from `Transaction.currentEntitlements`, which is StoreKit's own
/// source of truth. It already reflects restored purchases, Family Sharing, and purchases made
/// on the user's other devices, so there is no receipt to parse and — importantly — no local
/// "hasPurchased" flag to keep in sync. A local flag is the classic bug in this layer: it drifts
/// from reality on refund, reinstall and device switch, and every attempt to patch it adds
/// another way to be wrong.
///
/// A long-lived listener on `Transaction.updates` finishes transactions that arrive outside a
/// direct `purchase()` call — Ask-to-Buy approvals, purchases on another device, refunds — and
/// republishes freshly derived state on `isProUpdates`. Starting it at `init` (per Apple's
/// guidance) means a transaction posted while the app was still launching is never dropped.
///
/// This is an `actor` because `Transaction.updates` and the entitlement scan are concurrent;
/// the observable `Entitlements` wrapper is `@MainActor` and does the UI-facing part.
actor StoreKitEntitlementProvider: EntitlementProvider {
    private let productID: String
    /// Started in `init`, cancelled in `deinit`.
    ///
    /// `nonisolated(unsafe)` because it is written exactly once, from the initializer, before
    /// any other task can possibly reach this actor. The compiler cannot prove that, so the
    /// annotation is us asserting it. A plain `var` here is a warning today and an error in
    /// Swift 6 language mode; a `let` cannot work either, because the task closure captures
    /// `self` and so cannot run until initialization finishes. Do not write to this anywhere
    /// else, which is what would make the assertion false.
    private nonisolated(unsafe) var listener: Task<Void, Never>?

    nonisolated let isProUpdates: AsyncStream<Bool>
    private let isProContinuation: AsyncStream<Bool>.Continuation

    init(productID: String = StoreProduct.pro) {
        self.productID = productID
        let (stream, continuation) = AsyncStream.makeStream(of: Bool.self)
        self.isProUpdates = stream
        self.isProContinuation = continuation

        // Start listening immediately so a transaction posted at launch is never dropped.
        self.listener = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }
    }

    deinit {
        listener?.cancel()
        isProContinuation.finish()
    }

    // MARK: - EntitlementProvider

    func currentIsPro() async -> Bool {
        await hasProEntitlement()
    }

    func purchasePro() async throws -> Bool {
        let products = try await Product.products(for: [productID])
        guard let product = products.first else { throw StoreError.productNotFound }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try Self.checkVerified(verification)
            // Mark it handled so StoreKit stops redelivering it on the updates stream.
            await transaction.finish()
            return transaction.productID == productID && transaction.revocationDate == nil
        case .userCancelled:
            return false
        case .pending:
            // Deferred, e.g. Ask to Buy. The `Transaction.updates` listener finishes it once
            // approved and the UI reflects Pro then. Returning false here is correct: nothing
            // is unlocked *yet*.
            return false
        @unknown default:
            return false
        }
    }

    func restore() async throws -> Bool {
        // For a non-consumable, `currentEntitlements` already reflects restored purchases.
        // `AppStore.sync()` forces a refresh from the App Store and may prompt for auth.
        //
        // The error handling here is deliberate and worth preserving: a user CANCELLING the
        // auth prompt must not block re-deriving from local entitlements, but a real failure
        // (offline, store down) MUST surface. Swallowing both means an owner with no cached
        // entitlement sees "no purchase found" — telling a paying customer they never paid —
        // when the truth is "couldn't reach the store".
        do {
            try await AppStore.sync()
        } catch StoreKitError.userCancelled {
            // Fall through and report whatever local entitlements say.
        }
        return await hasProEntitlement()
    }

    // MARK: - Internals

    /// Handle a transaction delivered on `Transaction.updates`, outside a direct purchase call.
    private func handle(_ result: VerificationResult<Transaction>) async {
        guard let transaction = try? Self.checkVerified(result) else { return }
        await transaction.finish()
        isProContinuation.yield(await hasProEntitlement())
    }

    /// The single source of truth for Pro. The matching rule itself is factored into the pure,
    /// unit-tested `isProEntitled(productID:entitlements:)` below.
    private func hasProEntitlement() async -> Bool {
        var entitlements: [Entitlement] = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            entitlements.append(Entitlement(productID: transaction.productID,
                                            revocationDate: transaction.revocationDate))
        }
        return Self.isProEntitled(productID: productID, entitlements: entitlements)
    }

    private static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
}

extension StoreKitEntitlementProvider {
    /// The bits of a `Transaction` the Pro decision actually depends on.
    ///
    /// Extracted so the rule is testable: only StoreKit can mint a real `Transaction`, so a
    /// decision written directly against that type is untestable by construction. Shrinking the
    /// input to a plain struct is the whole trick, and it generalises to any Apple type you
    /// cannot instantiate.
    struct Entitlement {
        let productID: String
        let revocationDate: Date?
    }

    /// Pure decision: does any current entitlement unlock Pro?
    ///
    /// Pro requires an entitlement for exactly this product that has NOT been revoked. The
    /// revocation check is what handles refunds — without it a refunded user keeps the feature.
    static func isProEntitled(productID: String, entitlements: [Entitlement]) -> Bool {
        entitlements.contains { $0.productID == productID && $0.revocationDate == nil }
    }
}
