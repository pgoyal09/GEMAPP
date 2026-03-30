import Foundation
import SwiftData
import os

private let logger = Logger(subsystem: "com.qdi.gemapp", category: "transaction")

/// Errors thrown by transaction operations.
enum TransactionError: LocalizedError {
    case stoneNotAvailable(sku: String, status: String)
    case stoneOnMemo(sku: String)
    case duplicateStone(sku: String)
    case stoneAlreadyOnMemo(sku: String, ref: String)
    case stoneAlreadyOnInvoice(sku: String, ref: String)
    case invalidCaratWeight
    case lotInsufficientCarats(available: Double, requested: Double)

    var errorDescription: String? {
        switch self {
        case .stoneNotAvailable(let sku, let status):
            return "Stone \(sku) is not available (current status: \(status))."
        case .stoneOnMemo(let sku):
            return "Stone \(sku) is currently on a memo. Use Convert to Invoice from the memo instead."
        case .duplicateStone(let sku):
            return "Stone \(sku) is already in this document."
        case .stoneAlreadyOnMemo(let sku, let ref):
            return "Stone \(sku) is already on memo \(ref). Return it first."
        case .stoneAlreadyOnInvoice(let sku, let ref):
            return "Stone \(sku) is already on invoice \(ref)."
        case .invalidCaratWeight:
            return "Carat weight must be greater than zero."
        case .lotInsufficientCarats(let available, let requested):
            return "Insufficient lot carats. Available: \(String(format: "%.2f", available)), requested: \(String(format: "%.2f", requested))."
        }
    }
}

/// Core transaction operations shared by memos and invoices.
/// All methods throw on failure — callers handle errors in the UI layer.
enum TransactionService {

    // MARK: - Create Documents

    @MainActor
    static func createMemo(modelContext: ModelContext) throws -> Memo {
        let ref = ReferenceNumberGenerator.nextMemoNumber(modelContext: modelContext)
        let memo = Memo(status: .onMemo, dateAssigned: Date(), referenceNumber: ref)
        modelContext.insert(memo)
        try modelContext.save()
        return memo
    }

    @MainActor
    static func createInvoice(modelContext: ModelContext) throws -> Invoice {
        let ref = ReferenceNumberGenerator.nextInvoiceNumber(modelContext: modelContext)
        let invoice = Invoice(referenceNumber: ref, status: .draft)
        modelContext.insert(invoice)
        try modelContext.save()
        return invoice
    }

    // MARK: - Add Line Items to Memo

    @MainActor
    static func addStone(_ stone: Gemstone, to memo: Memo, modelContext: ModelContext) throws {
        // Guard: stone must be in stock
        guard stone.status == .available else {
            throw TransactionError.stoneNotAvailable(sku: stone.sku, status: stone.status.rawValue)
        }
        // Guard: stone must not already be in the memo
        if memo.lineItems.contains(where: { $0.gemstone?.persistentModelID == stone.persistentModelID }) {
            throw TransactionError.duplicateStone(sku: stone.sku)
        }
        // Guard: stone must not be on ANY other memo with an active line item
        let stoneID = stone.persistentModelID
        let openStatus = LineItemStatus.open
        let allLineItems = FetchDescriptor<LineItem>(
            predicate: #Predicate<LineItem> { item in
                item.gemstone?.persistentModelID == stoneID &&
                item.memo != nil &&
                item.status == openStatus
            }
        )
        if let existingItems = try? modelContext.fetch(allLineItems),
           let existingItem = existingItems.first(where: { $0.memo?.persistentModelID != memo.persistentModelID }) {
            let ref = existingItem.memo?.referenceNumber ?? "unknown"
            throw TransactionError.stoneAlreadyOnMemo(sku: stone.sku, ref: ref)
        }
        // Guard: carat weight must be positive
        guard stone.caratWeight > 0 else {
            throw TransactionError.invalidCaratWeight
        }
        // Warning: zero price
        if stone.sellPrice == 0 {
            HistoryLogger.logQuietly(stone: stone, type: .priceUpdated,
                                      message: "Warning: Stone added with zero sell price", modelContext: modelContext)
        }

        let desc = StoneDescriptionBuilder.buildDescription(for: stone)
        let amount = stone.sellPrice * Decimal(stone.caratWeight)
        let item = LineItem(
            sku: stone.sku,
            itemDescription: desc,
            carats: stone.caratWeight,
            rate: stone.sellPrice,
            amount: amount,
            kind: .inventory,
            gemstone: stone
        )
        modelContext.insert(item)
        item.memo = memo
        stone.memo = memo
        stone.status = .onMemo
        let custName = memo.customer?.displayName ?? "Unknown"
        HistoryLogger.logQuietly(stone: stone, type: .sentToCustomer,
                                  message: "On memo to \(custName)", modelContext: modelContext)
        try modelContext.save()
    }

    @MainActor
    static func addBrokeredLine(to memo: Memo, modelContext: ModelContext) throws {
        let item = LineItem(kind: .brokered)
        modelContext.insert(item)
        item.memo = memo
        try modelContext.save()
    }

    @MainActor
    static func addServiceLine(to memo: Memo, modelContext: ModelContext) throws {
        let item = LineItem(itemDescription: "Shipping / Service", kind: .service)
        modelContext.insert(item)
        item.memo = memo
        try modelContext.save()
    }

    // MARK: - Add Line Items to Invoice

    @MainActor
    static func addStone(_ stone: Gemstone, to invoice: Invoice, modelContext: ModelContext) throws {
        // Guard: stone on memo must go through memo-to-invoice conversion
        if stone.status == .onMemo {
            throw TransactionError.stoneOnMemo(sku: stone.sku)
        }
        // Guard: stone must be in stock (not sold or on memo)
        guard stone.status == .available else {
            throw TransactionError.stoneNotAvailable(sku: stone.sku, status: stone.status.rawValue)
        }
        // Guard: stone must not already be in the invoice
        if invoice.lineItems.contains(where: { $0.gemstone?.persistentModelID == stone.persistentModelID }) {
            throw TransactionError.duplicateStone(sku: stone.sku)
        }
        // Guard: stone must not be on ANY other invoice with an active line item
        let stoneID = stone.persistentModelID
        let soldStatus = LineItemStatus.sold
        let openStatus = LineItemStatus.open
        let allInvoiceItems = FetchDescriptor<LineItem>(
            predicate: #Predicate<LineItem> { item in
                item.gemstone?.persistentModelID == stoneID &&
                item.invoice != nil &&
                (item.status == soldStatus || item.status == openStatus)
            }
        )
        if let existingItems = try? modelContext.fetch(allInvoiceItems),
           let existingItem = existingItems.first(where: { $0.invoice?.persistentModelID != invoice.persistentModelID }) {
            let ref = existingItem.invoice?.referenceNumber ?? "unknown"
            throw TransactionError.stoneAlreadyOnInvoice(sku: stone.sku, ref: ref)
        }
        // Guard: carat weight must be positive
        guard stone.caratWeight > 0 else {
            throw TransactionError.invalidCaratWeight
        }
        // Warning: zero price
        if stone.sellPrice == 0 {
            HistoryLogger.logQuietly(stone: stone, type: .priceUpdated,
                                      message: "Warning: Stone added to invoice with zero sell price", modelContext: modelContext)
        }

        let desc = StoneDescriptionBuilder.buildDescription(for: stone)
        let amount = stone.sellPrice * Decimal(stone.caratWeight)
        let item = LineItem(
            sku: stone.sku,
            itemDescription: desc,
            carats: stone.caratWeight,
            rate: stone.sellPrice,
            amount: amount,
            kind: .inventory,
            gemstone: stone
        )
        modelContext.insert(item)
        item.invoice = invoice
        stone.memo = nil
        stone.status = .sold
        let custName = invoice.customer?.displayName ?? "Unknown"
        HistoryLogger.logQuietly(stone: stone, type: .sold,
                                  message: "Sold to \(custName)", modelContext: modelContext)
        try modelContext.save()
    }

    @MainActor
    static func addBrokeredLine(to invoice: Invoice, modelContext: ModelContext) throws {
        let item = LineItem(kind: .brokered)
        modelContext.insert(item)
        item.invoice = invoice
        try modelContext.save()
    }

    @MainActor
    static func addServiceLine(to invoice: Invoice, modelContext: ModelContext) throws {
        let item = LineItem(itemDescription: "Shipping / Service", kind: .service)
        modelContext.insert(item)
        item.invoice = invoice
        try modelContext.save()
    }

    // MARK: - Remove Line Item

    @MainActor
    static func removeLineItem(_ item: LineItem, restoreStone: Bool = true, modelContext: ModelContext) throws {
        if restoreStone, let stone = item.gemstone {
            if item.isLotLineItem {
                stone.effectiveRemainingCarats += item.carats
            } else {
                stone.status = .available
                stone.memo = nil
            }
        }
        modelContext.delete(item)
        try modelContext.save()
    }
}
