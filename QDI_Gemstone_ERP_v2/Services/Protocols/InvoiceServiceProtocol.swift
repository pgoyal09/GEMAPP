import Foundation
import SwiftData

/// Protocol abstracting invoice business operations for testability.
/// Conformers handle marking items as sold, voiding, deleting, and payment operations.
@MainActor
protocol InvoiceServiceProtocol {
    /// Mark converted line items (from memo) as sold when invoice is saved.
    static func markConvertedItemsAsSold(invoice: Invoice, modelContext: ModelContext)

    /// Mark lot line items as sold and record lot transactions.
    static func markLotItemsAsSold(invoice: Invoice, modelContext: ModelContext)

    /// Void an invoice: restores linked gemstones to available.
    static func voidInvoice(_ invoice: Invoice, modelContext: ModelContext) throws

    /// Delete an invoice: restores stones, deletes line items and invoice.
    static func deleteInvoice(_ invoice: Invoice, modelContext: ModelContext) throws

    /// Mark invoice as paid. Also ensures all line items are marked .sold.
    static func markAsPaid(_ invoice: Invoice, modelContext: ModelContext) throws
}
