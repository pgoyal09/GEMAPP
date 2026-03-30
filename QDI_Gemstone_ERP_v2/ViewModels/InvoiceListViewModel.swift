import Foundation
import SwiftData

@MainActor
@Observable
final class InvoiceListViewModel {
    var searchText: String = ""
    var statusFilter: InvoiceStatus? = nil
    var selectedInvoiceID: PersistentIdentifier? = nil

    // MARK: - Pagination

    var currentPage: Int = 0
    var pageSize: Int = 50
    var hasMorePages: Bool = false

    /// Fetch a paginated batch of invoices from the model context.
    func fetchPage(modelContext: ModelContext) -> [Invoice] {
        var descriptor = FetchDescriptor<Invoice>(
            sortBy: [SortDescriptor(\.invoiceDate, order: .reverse)]
        )
        descriptor.fetchLimit = pageSize
        descriptor.fetchOffset = currentPage * pageSize
        let results = (try? modelContext.fetch(descriptor)) ?? []
        let totalCount = (try? modelContext.fetchCount(FetchDescriptor<Invoice>())) ?? 0
        hasMorePages = (currentPage + 1) * pageSize < totalCount
        return results
    }

    /// Load the next page.
    func loadMore(modelContext: ModelContext) -> [Invoice] {
        guard hasMorePages else { return [] }
        currentPage += 1
        return fetchPage(modelContext: modelContext)
    }

    /// Reset pagination.
    func resetPagination() {
        currentPage = 0
        hasMorePages = false
    }

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
