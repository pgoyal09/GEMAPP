import Foundation
import SwiftData

/// Protocol abstracting memo business operations for testability.
/// Conformers handle returning items, auto-closing, converting to invoice, and deletion.
@MainActor
protocol MemoServiceProtocol {
    /// Return selected items from a memo to stock.
    static func returnItems(_ items: [LineItem], modelContext: ModelContext) throws

    /// Checks if all line items are resolved and auto-closes the memo.
    static func checkAndAutoClose(memo: Memo, modelContext: ModelContext)

    /// Convert selected memo line items to a new invoice.
    static func convertToInvoice(
        memo: Memo,
        selectedItems: [LineItem],
        modelContext: ModelContext
    ) throws -> Invoice?

    /// Delete a memo and return all open items to stock.
    static func deleteMemo(_ memo: Memo, modelContext: ModelContext) throws
}
