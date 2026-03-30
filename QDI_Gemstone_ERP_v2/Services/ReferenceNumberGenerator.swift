import Foundation
import SwiftData

/// Generates auto-incrementing reference numbers for memos and invoices.
enum ReferenceNumberGenerator {

    /// Next memo number: max(existing) + 1, starting at 1001.
    /// Optimized: sort descending + fetchLimit 1 instead of loading all memos.
    @MainActor
    static func nextMemoNumber(modelContext: ModelContext) -> String {
        var descriptor = FetchDescriptor<Memo>(
            sortBy: [SortDescriptor(\.referenceNumber, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        guard let memos = try? modelContext.fetch(descriptor),
              let latest = memos.first,
              let maxNum = Int(latest.referenceNumber) else {
            return "1001"
        }
        return "\(max(maxNum + 1, 1001))"
    }

    /// Next invoice number: max(existing) + 1, starting at 2001. Handles "INV-XXXX" prefix.
    /// Optimized: sort descending + fetchLimit 1 instead of loading all invoices.
    @MainActor
    static func nextInvoiceNumber(modelContext: ModelContext) -> String {
        var descriptor = FetchDescriptor<Invoice>(
            sortBy: [SortDescriptor(\.referenceNumber, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        guard let invoices = try? modelContext.fetch(descriptor),
              let latest = invoices.first else {
            return "2001"
        }
        let ref = latest.referenceNumber
        let s = ref.hasPrefix("INV-") ? String(ref.dropFirst(4)) : ref
        guard let maxNum = Int(s) else { return "2001" }
        return "\(max(maxNum + 1, 2001))"
    }
}
