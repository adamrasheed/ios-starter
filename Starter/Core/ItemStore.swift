import Foundation
import SwiftData

/// EXAMPLE STORE. Delete alongside `ExampleItem`.
///
/// The pattern is the point, and it is the single biggest lever on how testable an app is:
/// **mutation logic lives here, not in views.**
///
/// SwiftData makes it very easy to call `modelContext.insert(...)` directly from a button
/// action. That works, and it makes the rule untestable: verifying "deleting an item
/// renumbers the rest correctly" then requires launching a UI test, which is slow, flaky, and
/// something you will quietly stop running. With the logic here, the same check is a
/// millisecond-fast unit test against an in-memory `ModelContext` (see `ItemStoreTests`).
///
/// Rule of thumb: views call methods on a store; views do not touch `ModelContext`.
struct ItemStore {
    let context: ModelContext

    func all() throws -> [ExampleItem] {
        let descriptor = FetchDescriptor<ExampleItem>(
            sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdAt)]
        )
        return try context.fetch(descriptor)
    }

    @discardableResult
    func add(title: String, detail: String = "") throws -> ExampleItem {
        // Append at the end rather than assuming count == max order: after deletions, those
        // two disagree, and duplicate sortOrder values produce a list whose order changes
        // between launches. Users read that as the app losing their arrangement.
        let nextOrder = (try all().map(\.sortOrder).max() ?? -1) + 1
        let item = ExampleItem(title: title, detail: detail, sortOrder: nextOrder)
        context.insert(item)
        try context.save()
        return item
    }

    func delete(_ item: ExampleItem) throws {
        context.delete(item)
        try context.save()
        try renumber()
    }

    /// Reorder from a SwiftUI `.onMove`.
    func move(from source: IndexSet, to destination: Int) throws {
        var items = try all()
        items.move(fromOffsets: source, toOffset: destination)
        for (index, item) in items.enumerated() {
            item.sortOrder = index
        }
        try context.save()
    }

    /// Collapse gaps left by deletion so ordering stays dense and predictable.
    private func renumber() throws {
        for (index, item) in try all().enumerated() {
            item.sortOrder = index
        }
        try context.save()
    }
}
