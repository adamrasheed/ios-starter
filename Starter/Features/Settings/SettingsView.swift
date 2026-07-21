import SwiftUI

/// Settings.
///
/// Every shipping app needs these rows, and two of them are App Store review requirements
/// rather than nice-to-haves: **Restore Purchases** (mandatory for non-consumables) and a
/// reachable **Privacy Policy** link (mandatory, and it must be a live URL at review time —
/// a 404 here is a routine rejection).
struct SettingsView: View {
    @Environment(Entitlements.self) private var entitlements
    @State private var isRestoring = false
    @State private var showPaywall = false

    // REPLACE with your real URLs before submitting.
    private let privacyURL = URL(string: "https://example.com/privacy")!
    private let supportURL = URL(string: "https://example.com/support")!

    var body: some View {
        NavigationStack {
            Form {
                Section("Pro") {
                    LabeledContent("Status") {
                        Text(entitlements.isPro ? "Unlocked" : "Free")
                            .foregroundStyle(entitlements.isPro ? Color.brand : .textSecondary)
                    }

                    // Hidden once Pro is unlocked: there is nothing left to sell, and leaving a
                    // buy button in front of someone who already paid is how you generate
                    // "I was charged twice" support mail.
                    if !entitlements.isPro {
                        Button {
                            showPaywall = true
                        } label: {
                            HStack {
                                Label("Unlock Pro", systemImage: "sparkles")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.textTertiary)
                            }
                        }
                    }

                    Button {
                        isRestoring = true
                        Task {
                            defer { isRestoring = false }
                            try? await entitlements.restore()
                        }
                    } label: {
                        HStack {
                            Text("Restore Purchases")
                            if isRestoring {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isRestoring)
                }

                Section("About") {
                    LabeledContent("Version", value: AppInfo.displayVersion)
                    Link("Privacy Policy", destination: privacyURL)
                    Link("Support", destination: supportURL)
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showPaywall) {
                PaywallView()
                    // Sheets inherit the environment, but passing it explicitly keeps the
                    // paywall correct no matter how it ends up being presented later.
                    .environment(entitlements)
            }
        }
    }
}
