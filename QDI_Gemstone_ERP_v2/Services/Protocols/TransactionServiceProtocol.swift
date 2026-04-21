import Foundation
import SwiftData

/// Protocol abstracting core transaction operations for testability.
/// Conformers handle document creation, line item management, and stone lifecycle.
@MainActor
protocol TransactionServiceProtocol {
    // MARK: - Create Documents
    static func createMemo(modelContext: ModelContext) throws -> Memo
    static func createInvoice(modelContext: ModelContext) throws -> Invoice

    // MARK: - Add Line Items to Memo
    static func addStone(_ stone: Gemstone, to memo: Memo, modelContext: ModelContext) throws
    static func addBrokeredLine(to memo: Memo, modelContext: ModelContext) throws
    static func addServiceLine(to memo: Memo, modelContext: ModelContext) throws

    // MARK: - Add Line Items to Invoice
    static func addStone(_ stone: Gemstone, to invoice: Invoice, modelContext: ModelContext) throws
    static func addBrokeredLine(to invoice: Invoice, modelContext: ModelContext) throws
    static func addServiceLine(to invoice: Invoice, modelContext: ModelContext) throws

    // MARK: - Remove Line Item
    static func removeLineItem(_ item: LineItem, restoreStone: Bool, modelContext: ModelContext) throws
}
