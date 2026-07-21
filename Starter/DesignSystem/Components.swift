import SwiftUI

// Shared view components built from the tokens in `Theme.swift`.
//
// These cover the states every app needs and most apps write badly or forget entirely: empty,
// loading, error, and the primary call to action. Having them here means a new screen gets
// good behaviour by default rather than by remembering.

// MARK: - Empty state

/// What a list shows when it has nothing in it.
///
/// An empty list that renders as a blank screen reads as a bug. An empty state that names what
/// is missing and offers the action that fixes it is the single highest-leverage piece of
/// polish in most apps, because it is what a brand-new user sees FIRST.
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: Spacing.m) {
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundStyle(.textTertiary)

            Text(title)
                .font(AppFont.title)
                .foregroundStyle(.textPrimary)

            Text(message)
                .font(AppFont.caption)
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .padding(.top, Spacing.xs)
            }
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Loading state

struct LoadingView: View {
    var message: String?

    var body: some View {
        VStack(spacing: Spacing.m) {
            ProgressView()
            if let message {
                Text(message)
                    .font(AppFont.caption)
                    .foregroundStyle(.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Without this, VoiceOver announces nothing while the screen sits there apparently
        // frozen.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message ?? "Loading")
    }
}

// MARK: - Error state

/// A full-screen failure with a way out.
///
/// Always give a retry. A dead end forces the user to kill the app, and that is the moment
/// they decide whether to reopen it.
struct ErrorStateView: View {
    let message: String
    var retry: (() -> Void)?

    var body: some View {
        VStack(spacing: Spacing.m) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.orange)

            Text("Something went wrong")
                .font(AppFont.title)

            Text(message)
                .font(AppFont.caption)
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)

            if let retry {
                Button("Try Again", action: retry)
                    .buttonStyle(.bordered)
                    .padding(.top, Spacing.xs)
            }
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Primary action

/// The full-width call to action, with a built-in busy state.
///
/// The `isLoading` handling is the part worth having: it swaps in a spinner AND disables the
/// button, which is what stops a double-tap from firing two purchases or two network writes.
struct PrimaryButton: View {
    let title: String
    var isLoading = false
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(title)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(isLoading || !isEnabled)
    }
}

// MARK: - Card

/// A grouped container that sits on the screen background.
struct Card<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(Spacing.l)
            .background(.surfaceElevated, in: RoundedRectangle(cornerRadius: Radius.medium))
    }
}

// MARK: - Previews

#Preview("Empty") {
    EmptyStateView(icon: "tray",
                   title: "Nothing here yet",
                   message: "Items you add will show up on this screen.",
                   actionTitle: "Add the first one") {}
}

#Preview("Error") {
    ErrorStateView(message: "We couldn't reach the server. Check your connection.") {}
}
