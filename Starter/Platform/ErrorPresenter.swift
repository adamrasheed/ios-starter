import SwiftUI

/// One way to show the user that something failed.
///
/// Without a shared presenter, error handling decays into a mix of `try?` (silent failure —
/// the worst outcome, because the user thinks it worked), bespoke `@State var errorMessage`
/// in every view, and the occasional `fatalError` that ships. This gives every screen the
/// same one-liner and makes silence a deliberate choice rather than the path of least
/// resistance.
///
/// Usage:
///
///     @Environment(ErrorPresenter.self) private var errors
///
///     Button("Save") {
///         Task { await errors.attempt { try await store.save(item) } }
///     }
///
/// `RootView` installs `.errorAlert()` once, so nothing else needs to present anything.
@MainActor
@Observable
final class ErrorPresenter {
    private(set) var current: PresentedError?

    struct PresentedError: Identifiable {
        let id = UUID()
        let title: String
        let message: String
        let retry: (() async -> Void)?
    }

    /// Show a failure. Prefer `attempt` below, which does this for you.
    func present(_ error: Error,
                 title: String = "Something went wrong",
                 retry: (() async -> Void)? = nil) {
        // LocalizedError first: it is where you put the sentence a USER should read.
        // `localizedDescription` on an arbitrary error often yields something like
        // "The operation couldn't be completed. (MyApp.StoreError error 1.)", which is
        // developer text leaking into the UI.
        let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        AppLog.app.error("Presented error: \(String(describing: error), privacy: .public)")
        current = PresentedError(title: title, message: message, retry: retry)
    }

    func dismiss() {
        current = nil
    }

    /// Run work, presenting anything it throws. Returns the value, or nil if it failed.
    ///
    /// This is the honest replacement for `try?`. Same brevity at the call site, but the user
    /// finds out.
    @discardableResult
    func attempt<T>(title: String = "Something went wrong",
                    retry: (() async -> Void)? = nil,
                    _ work: () async throws -> T) async -> T? {
        do {
            return try await work()
        } catch is CancellationError {
            // A cancelled task is not a failure. Showing an alert when a user navigates away
            // mid-request is a classic false alarm.
            return nil
        } catch {
            present(error, title: title, retry: retry)
            return nil
        }
    }
}

extension View {
    /// Installs the app-wide error alert. Apply once, at the root.
    func errorAlert(_ presenter: ErrorPresenter) -> some View {
        alert(item: Binding(get: { presenter.current },
                            set: { if $0 == nil { presenter.dismiss() } })) { presented in
            Alert(
                title: Text(presented.title),
                message: Text(presented.message),
                dismissButton: .default(Text("OK")) { presenter.dismiss() }
            )
        }
    }
}
