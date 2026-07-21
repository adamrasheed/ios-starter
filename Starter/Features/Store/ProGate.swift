import SwiftUI

/// Wraps content that requires Pro. When locked it disables and veils the content and offers
/// an unlock affordance.
///
/// The value of having exactly one of these is consistency: every paid surface locks the same
/// way, so there is no screen where the gate was forgotten or implemented slightly differently.
/// Adding a paid feature is one modifier, not a design decision.
///
///     MyProFeature()
///         .proGated(entitlements.isPro) { showPaywall = true }
///         .paywallSheet(isPresented: $showPaywall)
struct ProGate: ViewModifier {
    let isPro: Bool
    let onUpgrade: () -> Void

    func body(content: Content) -> some View {
        if isPro {
            content
        } else {
            content
                .disabled(true)
                .blur(radius: 3)
                // Hide the veiled content from assistive tech: it is decorative once locked,
                // and VoiceOver reading a blurred, non-interactive feature is pure confusion.
                .accessibilityHidden(true)
                .overlay {
                    VStack(spacing: Spacing.s) {
                        Image(systemName: "lock.fill")
                            .font(.title3)
                        Button("Unlock Pro", action: onUpgrade)
                            .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
        }
    }
}

extension View {
    func proGated(_ isPro: Bool, onUpgrade: @escaping () -> Void) -> some View {
        modifier(ProGate(isPro: isPro, onUpgrade: onUpgrade))
    }
}
