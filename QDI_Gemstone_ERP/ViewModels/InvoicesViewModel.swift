import Foundation
import SwiftData

@MainActor
@Observable
final class InvoicesViewModel {
    var invoices: [Invoice] = []
    
    func load(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Invoice>(
            sortBy: [SortDescriptor(\.invoiceDate, order: .reverse)]
        )
        invoices = (try? modelContext.fetch(descriptor)) ?? []
    }
}
