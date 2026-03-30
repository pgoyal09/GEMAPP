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

    // MARK: - Pagination

    private(set) var fetchedInvoices: [Invoice] = []
    private(set) var hasMore = true
    private let pageSize = 50
    private var currentOffset = 0

    func fetchPage(context: ModelContext) {
        currentOffset = 0
        hasMore = true
        var descriptor = FetchDescriptor<Invoice>(
            predicate: buildPredicate(),
            sortBy: [SortDescriptor(\.invoiceDate, order: .reverse)]
        )
        descriptor.fetchLimit = pageSize
        fetchedInvoices = (try? context.fetch(descriptor)) ?? []
        currentOffset = fetchedInvoices.count
        hasMore = fetchedInvoices.count == pageSize
    }

    func loadMore(context: ModelContext) {
        guard hasMore else { return }
        var descriptor = FetchDescriptor<Invoice>(
            predicate: buildPredicate(),
            sortBy: [SortDescriptor(\.invoiceDate, order: .reverse)]
        )
        descriptor.fetchLimit = pageSize
        descriptor.fetchOffset = currentOffset
        let page = (try? context.fetch(descriptor)) ?? []
        fetchedInvoices.append(contentsOf: page)
        currentOffset += page.count
        hasMore = page.count == pageSize
    }

    /// Re-fetch with current predicate filters.
    func refetch(context: ModelContext) {
        fetchPage(context: context)
    }

    private func buildPredicate() -> Predicate<Invoice>? {
        guard let status = statusFilter else { return nil }
        let draftStatus = InvoiceStatus.draft
        let sentStatus = InvoiceStatus.sent
        let paidStatus = InvoiceStatus.paid
        let voidStatus = InvoiceStatus.void
        switch status {
        case .draft: return #Predicate<Invoice> { $0.status == draftStatus }
        case .sent: return #Predicate<Invoice> { $0.status == sentStatus }
        case .paid: return #Predicate<Invoice> { $0.status == paidStatus }
        case .void: return #Predicate<Invoice> { $0.status == voidStatus }
        }
    }

    func filtered(from invoices: [Invoice]) -> [Invoice] {
        var result = invoices

        // Status — handled by predicate

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
