import Foundation
import SwiftData

@MainActor
@Observable
final class MemoListViewModel: SortableViewModel {
    var searchText: String = ""
    var statusFilter: MemoStatus? = nil
    var selectedMemoID: PersistentIdentifier? = nil
    var sortKey: String = "date"
    var sortAscending: Bool = false

    // MARK: - Pagination

    private(set) var fetchedMemos: [Memo] = []
    private(set) var hasMore = true
    private let pageSize = 50
    private var currentOffset = 0

    func fetchPage(context: ModelContext) {
        currentOffset = 0
        hasMore = true
        var descriptor = FetchDescriptor<Memo>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        descriptor.fetchLimit = pageSize
        fetchedMemos = (try? context.fetch(descriptor)) ?? []
        currentOffset = fetchedMemos.count
        hasMore = fetchedMemos.count == pageSize
    }

    func loadMore(context: ModelContext) {
        guard hasMore else { return }
        var descriptor = FetchDescriptor<Memo>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        descriptor.fetchLimit = pageSize
        descriptor.fetchOffset = currentOffset
        let page = (try? context.fetch(descriptor)) ?? []
        fetchedMemos.append(contentsOf: page)
        currentOffset += page.count
        hasMore = page.count == pageSize
    }

    func filtered(from memos: [Memo]) -> [Memo] {
        var result = memos

        if let status = statusFilter {
            result = result.filter { $0.status == status }
        }

        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            result = result.filter { memo in
                memo.referenceNumber.lowercased().contains(q) ||
                (memo.customer?.displayName ?? "").lowercased().contains(q)
            }
        }

        return sorted(result)
    }

    // MARK: - Sorting

    private func sorted(_ memos: [Memo]) -> [Memo] {
        memos.sorted { a, b in
            let result: Bool
            switch sortKey {
            case "reference":
                result = a.referenceNumber.localizedCompare(b.referenceNumber) == .orderedAscending
            case "customer":
                result = (a.customer?.displayName ?? "").localizedCompare(b.customer?.displayName ?? "") == .orderedAscending
            case "status":
                result = a.status.rawValue.localizedCompare(b.status.rawValue) == .orderedAscending
            case "total":
                result = a.totalAmount < b.totalAmount
            default: // "date"
                result = a.createdAt < b.createdAt
            }
            return sortAscending ? result : !result
        }
    }
}
