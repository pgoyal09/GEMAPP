import Foundation
import SwiftData

@MainActor
@Observable
final class InvoiceListViewModel {
    var searchText: String = ""
    var statusFilter: InvoiceStatus? = nil
    var selectedInvoiceID: PersistentIdentifier? = nil

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

        return result
    }
}
