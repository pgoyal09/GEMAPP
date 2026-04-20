import Foundation
import SwiftData
import os

private let logger = Logger(subsystem: "com.qdi.gemapp", category: "invoice")

enum InvoiceError: LocalizedError {
    case cannotDeleteNonDraft(status: String)
    case cannotVoidInvoice(status: String)

    var errorDescription: String? {
        switch self {
        case .cannotDeleteNonDraft(let status): return "Cannot delete invoice with status '\(status)'. Only draft invoices can be deleted."
        case .cannotVoidInvoice(let status): return "Cannot void invoice with status '\(status)'. Only sent or paid invoices can be voided."
        }
    }
}

/// Invoice-specific business operations.
enum InvoiceService {

    /// Mark converted line items (from memo) as sold when invoice is saved.
    @MainActor
    static func markConvertedItemsAsSold(invoice: Invoice, modelContext: ModelContext) {
        let custName = invoice.customer?.displayName ?? "Unknown"
        for item in invoice.lineItems {
            guard let original = item.originLineItem else { continue }
            guard original.status != .sold else { continue } // Idempotency: skip already-sold
            original.status = .sold
            original.soldDate = Date()

            if let stone = item.gemstone {
                if item.isLotLineItem || original.isLotLineItem {
                    let lockedCost = original.lockedCostPerCarat ?? stone.effectiveAverageCost
                    item.lockedCostPerCarat = lockedCost
                    original.lockedCostPerCarat = lockedCost
                    let txn = LotTransaction(
                        type: .sold,
                        carats: item.carats,
                        pricePerCarat: item.rate,
                        totalPrice: item.amount,
                        lockedCostPerCarat: lockedCost,
                        notes: "Sold to \(custName) via Invoice \(invoice.referenceNumber)",
                        gemstone: stone
                    )
                    modelContext.insert(txn)
                    stone.lotTransactions.append(txn)
                    HistoryLogger.logQuietly(stone: stone, type: .sold,
                                              message: "Lot sold to \(custName)", modelContext: modelContext)
                } else {
                    stone.status = .sold
                    stone.memo = nil
                    HistoryLogger.logQuietly(stone: stone, type: .sold,
                                              message: "Sold to \(custName)", modelContext: modelContext)
                }
            }
        }
    }

    /// Mark lot line items as sold and record lot transactions.
    /// Skips items that came from memo conversion (those are handled by markConvertedItemsAsSold).
    @MainActor
    static func markLotItemsAsSold(invoice: Invoice, modelContext: ModelContext) {
        let custName = invoice.customer?.displayName ?? "Unknown"
        for item in invoice.lineItems where item.isLotLineItem {
            guard item.originLineItem == nil else { continue }
            guard let lot = item.gemstone else { continue }
            guard item.status != .sold else { continue } // Idempotency: skip already-sold
            item.status = .sold
            item.soldDate = Date()
            let lockedCost = item.lockedCostPerCarat ?? lot.effectiveAverageCost
            item.lockedCostPerCarat = lockedCost
            let txn = LotTransaction(
                type: .sold,
                carats: item.carats,
                pricePerCarat: item.rate,
                totalPrice: item.amount,
                lockedCostPerCarat: lockedCost,
                notes: "Sold to \(custName) via Invoice \(invoice.referenceNumber)",
                gemstone: lot
            )
            modelContext.insert(txn)
            lot.lotTransactions.append(txn)
            HistoryLogger.logQuietly(stone: lot, type: .sold,
                                      message: "Lot sold to \(custName)", modelContext: modelContext)
        }
    }

    /// Void an invoice: restores linked gemstones to available.
    @MainActor
    static func voidInvoice(_ invoice: Invoice, modelContext: ModelContext) throws {
        guard invoice.status == .sent || invoice.status == .paid else {
            throw InvoiceError.cannotVoidInvoice(status: invoice.status.rawValue)
        }
        invoice.status = .void
        for item in invoice.lineItems {
            // Reset origin memo line item if this was a conversion
            if let origin = item.originLineItem {
                origin.status = .open
                origin.soldDate = nil
            }
            if let stone = item.gemstone {
                if item.isLotLineItem {
                    stone.effectiveRemainingCarats += item.carats
                    // Create audit trail for lot reversal
                    let txn = LotTransaction(
                        type: .returned,
                        carats: item.carats,
                        pricePerCarat: item.rate,
                        totalPrice: item.amount,
                        notes: "Restored from voided Invoice #\(invoice.referenceNumber)",
                        gemstone: stone
                    )
                    modelContext.insert(txn)
                    stone.lotTransactions.append(txn)
                } else {
                    stone.status = .available
                    stone.memo = nil
                    HistoryLogger.logQuietly(stone: stone, type: .returnedFromCustomer,
                                              message: "Restored from voided Invoice #\(invoice.referenceNumber)", modelContext: modelContext)
                }
            }
        }
        try modelContext.save()
    }

    /// Delete an invoice: restores stones, deletes line items and invoice.
    @MainActor
    static func deleteInvoice(_ invoice: Invoice, modelContext: ModelContext) throws {
        // Only draft invoices can be deleted — sent/paid/void must be voided instead
        guard invoice.status == .draft else {
            throw InvoiceError.cannotDeleteNonDraft(status: invoice.status.rawValue)
        }
        for item in invoice.lineItems {
            // Reset origin memo line item if this was a conversion
            if let origin = item.originLineItem {
                origin.status = .open
                origin.soldDate = nil
            }
            if let stone = item.gemstone {
                if item.isLotLineItem {
                    stone.effectiveRemainingCarats += item.carats
                    // Create audit trail for lot reversal
                    let txn = LotTransaction(
                        type: .returned,
                        carats: item.carats,
                        pricePerCarat: item.rate,
                        totalPrice: item.amount,
                        notes: "Restored from deleted Invoice #\(invoice.referenceNumber)",
                        gemstone: stone
                    )
                    modelContext.insert(txn)
                    stone.lotTransactions.append(txn)
                } else {
                    stone.status = .available
                    stone.memo = nil
                    HistoryLogger.logQuietly(stone: stone, type: .returnedFromCustomer,
                                              message: "Restored from deleted Invoice #\(invoice.referenceNumber)", modelContext: modelContext)
                }
            }
            modelContext.delete(item)
        }
        modelContext.delete(invoice)
        try modelContext.save()
    }

    /// Mark invoice as paid.
    @MainActor
    static func markAsPaid(_ invoice: Invoice, modelContext: ModelContext) throws {
        invoice.status = .paid
        try modelContext.save()
    }
}
