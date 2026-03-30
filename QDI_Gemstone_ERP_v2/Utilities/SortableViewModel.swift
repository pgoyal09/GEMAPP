import Foundation

/// Shared sorting logic for ViewModels that have sortKey/sortAscending state.
@MainActor
protocol SortableViewModel: AnyObject {
    var sortKey: String { get set }
    var sortAscending: Bool { get set }
}

extension SortableViewModel {
    func toggleSort(_ key: String) {
        if sortKey == key {
            sortAscending.toggle()
        } else {
            sortKey = key
            sortAscending = true
        }
    }

    /// Generic sort helper: provide an ascending comparator for each sort key.
    func sortItems<T>(_ items: [T], using comparator: (T, T) -> Bool) -> [T] {
        items.sorted { a, b in
            sortAscending ? comparator(a, b) : comparator(b, a)
        }
    }
}
