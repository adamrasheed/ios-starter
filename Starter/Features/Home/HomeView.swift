import SwiftData
import SwiftUI

/// EXAMPLE SCREEN. Replace with your app's actual first tab.
///
/// It is here to show four things wired together correctly, which is faster to adapt than to
/// assemble from scratch: a SwiftData list that goes through `ItemStore` rather than touching
/// the context, a real empty state, error handling through the shared presenter, and a paid
/// feature behind `.proGated`.
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ErrorPresenter.self) private var errors
    @Environment(ReviewPrompt.self) private var reviewPrompt
    @Environment(Entitlements.self) private var entitlements

    @Query(sort: [SortDescriptor(\ExampleItem.sortOrder)]) private var items: [ExampleItem]
    @State private var showPaywall = false

    private var store: ItemStore { ItemStore(context: modelContext) }

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    EmptyStateView(icon: "tray",
                                   title: "Nothing here yet",
                                   message: "Items you add will show up on this screen.",
                                   actionTitle: "Add an item") { add() }
                } else {
                    list
                }
            }
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add", systemImage: "plus") { add() }
                }
            }
            .paywallSheet(isPresented: $showPaywall)
        }
    }

    private var list: some View {
        List {
            Section {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(item.title).font(AppFont.headline)
                        if !item.detail.isEmpty {
                            Text(item.detail)
                                .font(AppFont.caption)
                                .foregroundStyle(.textSecondary)
                        }
                    }
                }
                .onDelete(perform: delete)
                .onMove { source, destination in
                    Task { await errors.attempt { try store.move(from: source, to: destination) } }
                }
            }

            // A paid feature, gated in one line. Swap RootView's provider to
            // MockEntitlementProvider(isPro: true) to see the unlocked side.
            Section("Pro") {
                Text("An example paid feature.")
                    .font(AppFont.body)
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .proGated(entitlements.isPro) { showPaywall = true }
            }
        }
    }

    private func add() {
        Task {
            await errors.attempt {
                try store.add(title: "Item \(items.count + 1)", detail: "Tap Edit to reorder.")
            }
            Haptics.selection()
            // The core action succeeded, so this counts toward earning a review prompt.
            // Note it is on the SUCCESS path only.
            reviewPrompt.recordMilestone()
        }
    }

    private func delete(at offsets: IndexSet) {
        Task {
            for index in offsets {
                await errors.attempt { try store.delete(items[index]) }
            }
        }
    }
}
