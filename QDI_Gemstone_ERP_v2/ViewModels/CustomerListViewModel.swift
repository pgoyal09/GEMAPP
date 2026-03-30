import Foundation
import SwiftData

@MainActor
@Observable
final class CustomerListViewModel {
    var searchText: String = ""
    var selectedCustomerID: PersistentIdentifier? = nil
    var showAddCustomerSheet: Bool = false

    func filtered(from customers: [Customer]) -> [Customer] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return customers }
        return customers.filter { c in
            c.displayName.lowercased().contains(q) ||
            c.email.lowercased().contains(q) ||
            c.company.lowercased().contains(q)
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
