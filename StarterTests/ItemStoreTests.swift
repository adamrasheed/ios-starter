import Foundation
import SwiftData
import Testing
@testable import Starter

/// Tests for the example SwiftData store.
///
/// The technique to keep after you delete `ExampleItem`: an in-memory `ModelContainer` gives
/// each test a real, fully functional SwiftData stack that is created and thrown away in
/// microseconds, with no simulator state, no leftover files, and no ordering dependency between
/// tests. Persistence logic tested this way runs in the same breath as pure unit tests, which
/// is the difference between a suite you run on every save and one you run before releases.
@Suite("ItemStore")
@MainActor
struct ItemStoreTests {

    /// A fresh, isolated store per test.
    private func makeStore() throws -> ItemStore {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: ExampleItem.self, configurations: config)
        return ItemStore(context: ModelContext(container))
    }

    @Test("A new store is empty")
    func startsEmpty() throws {
        #expect(try makeStore().all().isEmpty)
    }

    @Test("Adding an item persists it")
    func addPersists() throws {
        let store = try makeStore()
        try store.add(title: "First", detail: "Detail")

        let items = try store.all()
        #expect(items.count == 1)
        #expect(items.first?.title == "First")
        #expect(items.first?.detail == "Detail")
    }

    @Test("Items are ordered by sortOrder, in insertion order")
    func ordersByInsertion() throws {
        let store = try makeStore()
        try store.add(title: "A")
        try store.add(title: "B")
        try store.add(title: "C")

        #expect(try store.all().map(\.title) == ["A", "B", "C"])
        #expect(try store.all().map(\.sortOrder) == [0, 1, 2])
    }

    @Test("Deleting removes only that item")
    func deleteRemovesOne() throws {
        let store = try makeStore()
        try store.add(title: "A")
        try store.add(title: "B")

        let toDelete = try #require(try store.all().first)
        try store.delete(toDelete)

        #expect(try store.all().map(\.title) == ["B"])
    }

    /// The regression this suite exists for. Deleting from the middle leaves a gap in
    /// `sortOrder`; the next `add` must not reuse an existing number, or two items share an
    /// order and the list silently reshuffles between launches.
    @Test("Order stays dense and unique after a delete")
    func renumbersAfterDelete() throws {
        let store = try makeStore()
        try store.add(title: "A")
        try store.add(title: "B")
        try store.add(title: "C")

        let middle = try #require(try store.all().first { $0.title == "B" })
        try store.delete(middle)

        let orders = try store.all().map(\.sortOrder)
        #expect(orders == [0, 1])
        #expect(Set(orders).count == orders.count, "sortOrder values must be unique")

        try store.add(title: "D")
        #expect(try store.all().map(\.title) == ["A", "C", "D"])
    }

    @Test("Moving an item rewrites the order")
    func moveReorders() throws {
        let store = try makeStore()
        try store.add(title: "A")
        try store.add(title: "B")
        try store.add(title: "C")

        // Move "C" (index 2) to the front.
        try store.move(from: IndexSet(integer: 2), to: 0)

        #expect(try store.all().map(\.title) == ["C", "A", "B"])
        #expect(try store.all().map(\.sortOrder) == [0, 1, 2])
    }
}
