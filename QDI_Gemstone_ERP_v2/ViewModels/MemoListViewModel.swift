import Foundation
import SwiftData

@MainActor
@Observable
final class MemoListViewModel {
    var searchText: String = ""
    var statusFilter: MemoStatus? = nil
    var selectedMemoID: PersistentIdentifier? = nil
    var sortKey: String = "date"
    var sortAscending: Bool = false

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

    func toggleSort(_ key: String) {
        if sortKey == key {
            sortAscending.toggle()
        } else {
            sortKey = key
            sortAscending = true
        }
    }

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
