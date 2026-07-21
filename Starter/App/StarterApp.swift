import SwiftData
import SwiftUI

@main
struct StarterApp: App {
    /// The SwiftData store.
    ///
    /// Built here rather than with the `.modelContainer(for:)` convenience so the failure path
    /// is explicit. The convenience form crashes the app on any container error, which in
    /// practice means a user with a corrupt store or a mismatched iCloud entitlement gets an
    /// app that cannot launch at all, with no way to tell you why.
    let modelContainer: ModelContainer

    /// App-wide services, created once and injected.
    ///
    /// This is the whole dependency-injection story: construct at the root, pass down the
    /// environment. No container framework, no service locator. When it stops being enough
    /// you will know, and until then this is less code and less indirection.
    @State private var errors = ErrorPresenter()
    @State private var reviewPrompt = ReviewPrompt()
    private let analytics: AnalyticsClient = ConsoleAnalyticsClient()

    init() {
        modelContainer = Self.makeContainer()
    }

    var body: some Scene {
        WindowGroup {
            RootView(analytics: analytics)
                .environment(errors)
                .environment(reviewPrompt)
                .errorAlert(errors)
        }
        .modelContainer(modelContainer)
    }

    // MARK: - Container

    private static func makeContainer() -> ModelContainer {
        let schema = Schema([ExampleItem.self])

        // Demo mode: an in-memory store seeded with presentable data, so App Store captures
        // show a populated app without touching (or requiring) real user data.
        if DemoMode.isActive {
            do {
                let config = ModelConfiguration(schema: schema,
                                                isStoredInMemoryOnly: true,
                                                cloudKitDatabase: .none)
                let container = try ModelContainer(for: schema, configurations: config)
                seedDemoData(into: ModelContext(container))
                return container
            } catch {
                fatalError("Demo-mode ModelContainer failed: \(error)")
            }
        }

        // Local store.
        //
        // TO ENABLE ICLOUD SYNC: swap `cloudKitDatabase` to `.private("iCloud.<your-bundle-id>")`,
        // add the iCloud + CloudKit capability, and read docs/adr/decision-log.md ADR-006 first.
        // Three things bite people, in order of how expensive they are to discover late:
        //   1. Every model property needs a default value and no unique constraints (see
        //      ExampleItem).
        //   2. Debug and Release need DIFFERENT aps-environment entitlements (development vs
        //      production). Ship the wrong one and sync fails in the App Store build only,
        //      with no error the user or you can see.
        //   3. A green build proves nothing about sync. The CloudKit schema must be deployed
        //      from Development to Production in the CloudKit Console as a separate manual
        //      step, and only a real two-device test confirms any of it works.
        let config = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            // Last resort: an in-memory store so the app still opens and the user can use it
            // for this session, rather than a launch crash they can only fix by deleting the
            // app. `assertionFailure` makes it loud in development and compiles out in release.
            assertionFailure("Persistent ModelContainer unavailable: \(error)")
            AppLog.data.error("Falling back to an in-memory store: \(String(describing: error), privacy: .public)")
            do {
                let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                return try ModelContainer(for: schema, configurations: fallback)
            } catch {
                fatalError("Could not create any ModelContainer: \(error)")
            }
        }
    }

    private static func seedDemoData(into context: ModelContext) {
        let store = ItemStore(context: context)
        _ = try? store.add(title: "First item", detail: "Seeded for screenshots.")
        _ = try? store.add(title: "Second item", detail: "Never touches real user data.")
        _ = try? store.add(title: "Third item", detail: "Deterministic, so captures are repeatable.")
    }
}
