import StoreKit
import SwiftUI

/// The paywall.
///
/// Presented by `.proGated(_:onUpgrade:)` and by the unlock row in Settings. Purchasing and
/// restoring both go through the shared `Entitlements` object, so `isPro` only ever changes in
/// one place; this view owns presentation and nothing else.
///
/// Three details here are load-bearing and commonly missed:
///   - **The price comes from StoreKit**, never a hardcoded string. Prices differ by storefront,
///     change with tax rules, and hardcoding one is a guaranteed lie for most of the world.
///   - **Restore is always visible.** Apple requires it for non-consumables, and a missing
///     restore button is a routine App Store rejection.
///   - **A price that fails to load does not disable restore.** An existing owner who opens this
///     offline still needs their unlock back.
struct PaywallView: View {
    @Environment(Entitlements.self) private var entitlements
    @Environment(\.dismiss) private var dismiss

    @State private var product: Product?
    @State private var loadState: LoadState = .loading
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var errorMessage: String?

    private enum LoadState { case loading, loaded, failed }

    /// All copy lives in `PaywallCopy` so it can be tested. Edit it there, not here.
    private var perks: [PaywallCopy.Perk] { PaywallCopy.perks }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.xl) {
                    header
                    perksList
                    Spacer(minLength: Spacing.s)
                    purchaseControls
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.vertical, Spacing.xxl)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task { await loadProduct() }
            // If Pro arrives while this is open (restored elsewhere, Ask-to-Buy approved,
            // bought on another device), there is nothing left to sell. Get out of the way.
            .onChange(of: entitlements.isPro) { _, isPro in
                if isPro { dismiss() }
            }
            .alert("Something went wrong",
                   isPresented: Binding(get: { errorMessage != nil },
                                        set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: Spacing.m) {
            Image(systemName: "sparkles")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.brand)
            Text(PaywallCopy.headline)
                .font(AppFont.display)
            Text(PaywallCopy.subhead)
                .font(AppFont.caption)
                .foregroundStyle(.textSecondary)
        }
        .padding(.top, Spacing.s)
    }

    private var perksList: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            ForEach(perks) { perk in
                HStack(alignment: .top, spacing: Spacing.m) {
                    Image(systemName: perk.icon)
                        .font(.title3)
                        .foregroundStyle(.brand)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(perk.title).font(AppFont.headline)
                        Text(perk.detail)
                            .font(AppFont.caption)
                            .foregroundStyle(.textSecondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var purchaseControls: some View {
        VStack(spacing: Spacing.m) {
            PrimaryButton(title: buyButtonTitle,
                          isLoading: isPurchasing,
                          isEnabled: !isRestoring && loadState != .failed,
                          action: buy)

            Button(action: restore) {
                if isRestoring {
                    ProgressView()
                } else {
                    Text(PaywallCopy.restoreTitle)
                }
            }
            .disabled(isPurchasing || isRestoring)

            if loadState == .failed {
                Text(PaywallCopy.priceUnavailable)
                    .font(AppFont.footnote)
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var buyButtonTitle: String {
        if let product { return "Unlock for \(product.displayPrice)" }
        return PaywallCopy.buyFallbackTitle
    }

    // MARK: - Actions

    private func loadProduct() async {
        do {
            let products = try await Product.products(for: [StoreProduct.pro])
            if let first = products.first {
                product = first
                loadState = .loaded
            } else {
                // Almost always a product-id mismatch between StoreProduct.pro, the .storekit
                // file, and App Store Connect, or a product still in "Waiting for Review".
                AppLog.store.error("No product returned for \(StoreProduct.pro, privacy: .public)")
                loadState = .failed
            }
        } catch {
            AppLog.store.error("Product load failed: \(String(describing: error), privacy: .public)")
            loadState = .failed
        }
    }

    private func buy() {
        isPurchasing = true
        Task {
            defer { isPurchasing = false }
            do {
                try await entitlements.purchasePro()
                if entitlements.isPro {
                    Haptics.success()
                    dismiss()
                }
            } catch {
                Haptics.failure()
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    private func restore() {
        isRestoring = true
        Task {
            defer { isRestoring = false }
            do {
                try await entitlements.restore()
                if entitlements.isPro {
                    Haptics.success()
                    dismiss()
                } else {
                    errorMessage = PaywallCopy.restoreFoundNothing
                }
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }
}

extension View {
    /// Presents the paywall as a sheet. Pair with `.proGated(_:onUpgrade:)`.
    ///
    /// The presenting view must have `Entitlements` in its environment; `RootView` injects it.
    func paywallSheet(isPresented: Binding<Bool>) -> some View {
        sheet(isPresented: isPresented) { PaywallView() }
    }
}
