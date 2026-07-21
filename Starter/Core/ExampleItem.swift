import Foundation
import SwiftData

/// EXAMPLE MODEL — delete this and `ItemStore` once you have a real domain.
///
/// It exists to demonstrate two constraints that are cheap to honour now and expensive to
/// retrofit once you have users with data on disk:
///
/// 1. **Every stored property has a default value, and there is no `@Attribute(.unique)`.**
///    Both are hard requirements for CloudKit mirroring. If you ever want SwiftData to sync
///    across a user's devices, a model that violates these will fail at container creation —
///    and adding defaults later means a migration, not an edit.
///
/// 2. **A canonical value, derived everywhere else.** `createdAt` is stored once; anything
///    displayed (a relative "2 days ago", a section header) is computed from it. Storing both
///    a value and a formatted copy of it guarantees they drift apart.
@Model
final class ExampleItem {
    var title: String = ""
    var detail: String = ""
    var createdAt: Date = Date.now
    /// Explicit user ordering. Kept separate from `createdAt` because "the order I arranged
    /// them in" and "when I made them" are different facts that users expect to control
    /// independently.
    var sortOrder: Int = 0

    init(title: String = "", detail: String = "", createdAt: Date = .now, sortOrder: Int = 0) {
        self.title = title
        self.detail = detail
        self.createdAt = createdAt
        self.sortOrder = sortOrder
    }
}
