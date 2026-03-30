import Foundation
import SwiftData

/// Generates auto-incrementing reference numbers for memos and invoices.
enum ReferenceNumberGenerator {

    /// Next memo number: max(existing) + 1, starting at 1001.
    @MainActor
    static func nextMemoNumber(modelContext: ModelContext) -> String {
        let descriptor = FetchDescriptor<Memo>()
        guard let memos = try? modelContext.fetch(descriptor) else { return "1001" }
        let maxNum = memos.compactMap { Int($0.referenceNumber) }.max()
        return "\(max((maxNum ?? 1000) + 1, 1001))"
    }

    /// Next invoice number: max(existing) + 1, starting at 2001. Handles "INV-XXXX" prefix.
    @MainActor
    static func nextInvoiceNumber(modelContext: ModelContext) -> String {
        let descriptor = FetchDescriptor<Invoice>()
        guard let invoices = try? modelContext.fetch(descriptor) else { return "2001" }
        let maxNum = invoices.compactMap { inv -> Int? in
            let ref = inv.referenceNumber
            let s = ref.hasPrefix("INV-") ? String(ref.dropFirst(4)) : ref
            return Int(s)
        }.max()
        return "\(max((maxNum ?? 2000) + 1, 2001))"
    }
}
