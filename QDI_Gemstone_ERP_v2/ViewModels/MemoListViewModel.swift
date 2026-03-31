import Foundation
import SwiftData
import os

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
        // SwiftData #Predicate does not support custom enum types as captured constants.
        // Fetch all memos and filter in memory instead.
        let descriptor = FetchDescriptor<Memo>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        do {
            let all = try context.fetch(descriptor)
            let filtered = applyStatusFilter(all)
            fetchedMemos = Array(filtered.prefix(pageSize))
        } catch {
            AppLogger.data.error("Memo fetch failed: \(error.localizedDescription, privacy: .public)")
            fetchedMemos = []
        }
        currentOffset = fetchedMemos.count
        hasMore = fetchedMemos.count == pageSize
    }

    func loadMore(context: ModelContext) {
        guard hasMore else { return }
        let descriptor = FetchDescriptor<Memo>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let page: [Memo]
        do {
            let all = try context.fetch(descriptor)
            let filtered = applyStatusFilter(all)
            page = Array(filtered.dropFirst(currentOffset).prefix(pageSize))
        } catch {
            AppLogger.data.error("Memo loadMore failed: \(error.localizedDescription, privacy: .public)")
            return
        }
        fetchedMemos.append(contentsOf: page)
        currentOffset += page.count
        hasMore = page.count == pageSize
    }

    /// Re-fetch with current predicate filters.
    func refetch(context: ModelContext) {
        fetchPage(context: context)
    }

    private func applyStatusFilter(_ memos: [Memo]) -> [Memo] {
        guard let status = statusFilter else { return memos }
        return memos.filter { $0.status == status }
    }

    func filtered(from memos: [Memo]) -> [Memo] {
        var result = memos

        // Status — handled by predicate

        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            result = result.filter { memo in
                memo.referenceNumber.lowercased().contains(q) ||
                (memo.customer?.displayName ?? "").lowercased().contains(q) ||
                (memo.salesperson ?? "").lowercased().contains(q)
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
            case "salesperson":
                result = (a.salesperson ?? "").localizedCompare(b.salesperson ?? "") == .orderedAscending
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
