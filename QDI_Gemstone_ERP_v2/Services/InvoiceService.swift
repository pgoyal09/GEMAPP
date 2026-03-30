import Foundation
import SwiftData
import os

private let logger = Logger(subsystem: "com.qdi.gemapp", category: "invoice")

/// Invoice-specific business operations.
enum InvoiceService {

    /// Mark converted line items (from memo) as sold when invoice is saved.
    @MainActor
    static func markConvertedItemsAsSold(invoice: Invoice, modelContext: ModelContext) {
        let custName = invoice.customer?.displayName ?? "Unknown"
        for item in invoice.lineItems {
            guard let original = item.originLineItem else { continue }
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
        invoice.status = .void
        for item in invoice.lineItems {
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
        for item in invoice.lineItems {
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
