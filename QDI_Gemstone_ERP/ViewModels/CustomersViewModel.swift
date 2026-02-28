import Foundation
import SwiftData

@MainActor
@Observable
final class CustomersViewModel {
    var customers: [Customer] = []
    
    func load(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Customer>(
            sortBy: [SortDescriptor(\.lastName), SortDescriptor(\.firstName)]
        )
        customers = (try? modelContext.fetch(descriptor)) ?? []
    }
}
