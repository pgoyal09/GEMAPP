import Foundation
import SwiftData
import os

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
        // SwiftData #Predicate does not support custom enum types as captured constants.
        // Fetch all invoices and filter in memory instead.
        let descriptor = FetchDescriptor<Invoice>(
            sortBy: [SortDescriptor(\.invoiceDate, order: .reverse)]
        )
        do {
            let all = try context.fetch(descriptor)
            let filtered = applyStatusFilter(all)
            fetchedInvoices = Array(filtered.prefix(pageSize))
        } catch {
            AppLogger.data.error("Invoice fetch failed: \(error.localizedDescription, privacy: .public)")
            fetchedInvoices = []
        }
        currentOffset = fetchedInvoices.count
        hasMore = fetchedInvoices.count == pageSize
    }

    func loadMore(context: ModelContext) {
        guard hasMore else { return }
        let descriptor = FetchDescriptor<Invoice>(
            sortBy: [SortDescriptor(\.invoiceDate, order: .reverse)]
        )
        let page: [Invoice]
        do {
            let all = try context.fetch(descriptor)
            let filtered = applyStatusFilter(all)
            page = Array(filtered.dropFirst(currentOffset).prefix(pageSize))
        } catch {
            AppLogger.data.error("Invoice loadMore failed: \(error.localizedDescription, privacy: .public)")
            return
        }
        fetchedInvoices.append(contentsOf: page)
        currentOffset += page.count
        hasMore = page.count == pageSize
    }

    /// Re-fetch with current predicate filters.
    func refetch(context: ModelContext) {
        fetchPage(context: context)
    }

    private func applyStatusFilter(_ invoices: [Invoice]) -> [Invoice] {
        guard let status = statusFilter else { return invoices }
        return invoices.filter { $0.status == status }
    }

    func filtered(from invoices: [Invoice]) -> [Invoice] {
        var result = invoices

        // Status — handled by predicate

        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            result = result.filter { inv in
                inv.referenceNumber.lowercased().contains(q) ||
                (inv.customer?.displayName ?? "").lowercased().contains(q) ||
                (inv.salesperson ?? "").lowercased().contains(q)
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
            case "salesperson":
                result = (a.salesperson ?? "").localizedCompare(b.salesperson ?? "") == .orderedAscending
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
