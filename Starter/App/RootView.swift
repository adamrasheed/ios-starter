import SwiftUI

/// The app shell: tabs, shared state, and the one place the paid boundary is wired up.
///
/// Everything shared is created HERE and injected downward. That single-construction-point rule
/// is what keeps entitlement state from disagreeing with itself across screens, and it means
/// swapping any dependency for a mock is a one-line edit in one file.
struct RootView: View {
    enum Tab: String, CaseIterable {
        case home, settings
    }

    let analytics: AnalyticsClient

    @Environment(\.scenePhase) private var scenePhase
    @Environment(ReviewPrompt.self) private var reviewPrompt

    @State private var entitlements: Entitlements
    @State private var selectedTab: Tab
    @AppStorage("onboarding.completed") private var hasCompletedOnboarding = false

    init(analytics: AnalyticsClient) {
        self.analytics = analytics

        // THE MOCK/REAL SWAP. During development, point this at
        // `MockEntitlementProvider(isPro: true)` to build and demo paid features with no
        // StoreKit, no App Store Connect product, and no signed agreements. This one line is
        // the entire integration when the real product is ready.
        if DemoMode.isActive {
            _entitlements = State(initialValue: Entitlements(
                provider: MockEntitlementProvider(isPro: DemoMode.forcesPro)
            ))
            _selectedTab = State(initialValue: Tab(rawValue: DemoMode.tab ?? "") ?? .home)
        } else {
            _entitlements = State(initialValue: Entitlements(
                provider: StoreKitEntitlementProvider()
            ))
            _selectedTab = State(initialValue: .home)
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }
                .tag(Tab.home)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(Tab.settings)
        }
        .environment(entitlements)
        .tint(.brand)
        // Runs for the app's lifetime: initial refresh plus the live updates stream that
        // applies refunds, Ask-to-Buy approvals and cross-device purchases.
        .task {
            analytics.track(.appLaunched)
            reviewPrompt.registerLaunch()
            await entitlements.activate()
        }
        // Belt and braces: re-check entitlements on every return to the foreground, in case a
        // transaction landed while the app was suspended and the stream did not deliver it.
        // Cheap, and it closes the "I bought it on my iPad and this one still says Free" gap.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await entitlements.refresh() }
            }
        }
        .fullScreenCover(isPresented: .constant(!hasCompletedOnboarding && !DemoMode.skipsOnboarding)) {
            OnboardingView {
                analytics.track(.onboardingCompleted)
                hasCompletedOnboarding = true
            }
        }
    }
}
