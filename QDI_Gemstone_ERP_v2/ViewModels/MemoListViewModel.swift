import Foundation
import SwiftData

@MainActor
@Observable
final class MemoListViewModel {
    var searchText: String = ""
    var statusFilter: MemoStatus? = nil
    var selectedMemoID: PersistentIdentifier? = nil

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

        return result
    }
}
