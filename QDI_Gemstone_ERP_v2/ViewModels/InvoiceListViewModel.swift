import Foundation
import SwiftData

@MainActor
@Observable
final class InvoiceListViewModel: SortableViewModel {
    var searchText: String = ""
    var statusFilter: InvoiceStatus? = nil
    var selectedInvoiceID: PersistentIdentifier? = nil
    var sortKey: String = "date"
    var sortAscending: Bool = false

    func filtered(from invoices: [Invoice]) -> [Invoice] {
        var result = invoices

        if let status = statusFilter {
            result = result.filter { $0.status == status }
        }

        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            result = result.filter { inv in
                inv.referenceNumber.lowercased().contains(q) ||
                (inv.customer?.displayName ?? "").lowercased().contains(q)
            }
        }

        return sorted(result)
    }

    // MARK: - Sorting

    private func sorted(_ invoices: [Invoice]) -> [Invoice] {
        invoices.sorted { a, b in
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
                result = a.invoiceDate < b.invoiceDate
            }
            return sortAscending ? result : !result
        }
    }
}
