import SwiftUI

/// First-run onboarding.
///
/// Keep it SHORT. Every screen between the user and the thing they downloaded your app for is
/// a place they abandon, and onboarding is not where people learn an app. Using it is. Three
/// pages is a reasonable ceiling; one is often better.
///
/// Two rules encoded here worth keeping:
///   - **Skip is always available.** Trapping someone in a tutorial is a good way to earn a
///     one-star review before they have seen the product.
///   - **No paywall here.** Asking for money before demonstrating value converts badly and
///     reads as a bait and switch. Gate the feature, not the front door.
struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var page = 0

    private struct Page: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let message: String
    }

    // REPLACE with your app's actual story. Lead with what the user gets, not what the app does.
    private let pages: [Page] = [
        Page(icon: "sparkles",
             title: "Welcome",
             message: "One sentence on the single thing this app does for you."),
        Page(icon: "hand.tap",
             title: "How it works",
             message: "One sentence on the core action, so the first tap is obvious."),
        Page(icon: "checkmark.seal",
             title: "You're set",
             message: "One closing line, then the button hands them the app. No tutorial, no "
                + "sell: the last page's whole job is to get out of the way."),
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.element.id) { index, item in
                    VStack(spacing: Spacing.l) {
                        Spacer()
                        Image(systemName: item.icon)
                            .font(.system(size: 64))
                            .foregroundStyle(.brand)
                        Text(item.title)
                            .font(AppFont.display)
                        Text(item.message)
                            .font(AppFont.body)
                            .foregroundStyle(.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Spacing.xl)
                        Spacer()
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page)

            VStack(spacing: Spacing.m) {
                PrimaryButton(title: page == pages.count - 1 ? "Get Started" : "Next") {
                    if page == pages.count - 1 {
                        Haptics.success()
                        onComplete()
                    } else {
                        withAnimation(Motion.standard) { page += 1 }
                    }
                }

                Button("Skip", action: onComplete)
                    .font(AppFont.caption)
                    .foregroundStyle(.textSecondary)
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.bottom, Spacing.xl)
        }
    }
}

#Preview {
    OnboardingView {}
}
