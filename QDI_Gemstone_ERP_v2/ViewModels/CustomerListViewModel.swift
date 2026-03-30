import Foundation
import SwiftData

@MainActor
@Observable
final class CustomerListViewModel {
    var searchText: String = ""
    var selectedCustomerID: PersistentIdentifier? = nil
    var showAddCustomerSheet: Bool = false
    var sortKey: String = "name"
    var sortAscending: Bool = true

    func filtered(from customers: [Customer]) -> [Customer] {
        var result = customers
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            result = result.filter { c in
                c.displayName.lowercased().contains(q) ||
                c.email.lowercased().contains(q) ||
                c.company.lowercased().contains(q)
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

    private func sorted(_ customers: [Customer]) -> [Customer] {
        customers.sorted { a, b in
            let result: Bool
            switch sortKey {
            case "company":
                result = a.company.localizedCompare(b.company) == .orderedAscending
            default: // "name"
                result = a.displayName.localizedCompare(b.displayName) == .orderedAscending
            }
            return sortAscending ? result : !result
        }
    }

    func deleteCustomer(_ customer: Customer, modelContext: ModelContext) throws {
        if !customer.memos.isEmpty {
            throw CustomerDeleteError.hasMemos(count: customer.memos.count)
        }
        if !customer.invoices.isEmpty {
            throw CustomerDeleteError.hasInvoices(count: customer.invoices.count)
        }
        modelContext.delete(customer)
        try modelContext.save()
        if selectedCustomerID == customer.persistentModelID {
            selectedCustomerID = nil
        }
    }

    enum CustomerDeleteError: LocalizedError {
        case hasMemos(count: Int)
        case hasInvoices(count: Int)

        var errorDescription: String? {
            switch self {
            case .hasMemos(let count):
                return "Cannot delete customer with \(count) memo(s). Remove or reassign memos first."
            case .hasInvoices(let count):
                return "Cannot delete customer with \(count) invoice(s). Remove or reassign invoices first."
            }
        }
    }
}
