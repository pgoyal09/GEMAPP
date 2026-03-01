import Foundation
import SwiftData

@MainActor
@Observable
final class CustomersViewModel {
    var customers: [Customer] = []
    var searchText: String = ""

    var filteredCustomers: [Customer] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return customers }
        return customers.filter { customer in
            customer.displayName.lowercased().contains(q) ||
            (customer.email ?? "").lowercased().contains(q) ||
            (customer.company ?? "").lowercased().contains(q)
        }
    }

    func load(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Customer>(
            sortBy: [SortDescriptor(\.lastName), SortDescriptor(\.firstName)]
        )
        customers = (try? modelContext.fetch(descriptor)) ?? []
    }
}
