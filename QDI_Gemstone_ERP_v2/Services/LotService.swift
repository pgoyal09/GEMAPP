import Foundation
import SwiftData

/// Operations specific to lot (bulk) gemstone inventory.
enum LotService {

    /// Add quantity to a lot: updates remaining carats, recalculates weighted average cost, records transaction.
    @MainActor
    static func addQuantity(
        to lot: Gemstone,
        carats: Double,
        costPerCarat: Decimal,
        date: Date = Date(),
        notes: String = "",
        modelContext: ModelContext
    ) throws {
        guard carats > 0, lot.isLot else { return }

        let existingCarats = lot.effectiveRemainingCarats
        let existingCost = lot.effectiveAverageCost
        let totalCarats = ((existingCarats + carats) * 10000).rounded() / 10000
        let newAvgCost = totalCarats > 0
            ? (existingCost * Decimal(existingCarats) + costPerCarat * Decimal(carats)) / Decimal(totalCarats)
            : costPerCarat

        lot.remainingCarats = totalCarats
        lot.averageCostPerCarat = newAvgCost

        let txn = LotTransaction(
            type: .added,
            carats: carats,
            date: date,
            pricePerCarat: costPerCarat,
            totalPrice: costPerCarat * Decimal(carats),
            notes: notes,
            gemstone: lot
        )
        modelContext.insert(txn)
        lot.lotTransactions.append(txn)
        try modelContext.save()
    }

    /// Add lot to memo: deducts carats, creates line item and lot transaction.
    @MainActor
    static func addToMemo(
        _ lot: Gemstone,
        carats: Double,
        memo: Memo,
        modelContext: ModelContext
    ) throws {
        guard lot.isLot else { return }
        guard carats > 0 else {
            throw TransactionError.invalidCaratWeight
        }
        guard carats <= lot.effectiveRemainingCarats else {
            throw TransactionError.lotInsufficientCarats(available: lot.effectiveRemainingCarats, requested: carats)
        }

        let rate = lot.sellPrice
        let amount = rate * Decimal(carats)
        let desc = StoneDescriptionBuilder.buildDescription(for: lot)
        let item = LineItem(
            sku: lot.sku,
            itemDescription: desc,
            carats: carats,
            rate: rate,
            amount: amount,
            kind: .inventory,
            isLotLineItem: true,
            lockedCostPerCarat: lot.effectiveAverageCost,
            gemstone: lot
        )
        modelContext.insert(item)
        item.memo = memo
        lot.effectiveRemainingCarats -= carats

        let custName = memo.customer?.displayName ?? "Unknown"
        let txn = LotTransaction(
            type: .onMemo,
            carats: carats,
            pricePerCarat: rate,
            totalPrice: amount,
            notes: "On memo to \(custName)",
            gemstone: lot
        )
        modelContext.insert(txn)
        lot.lotTransactions.append(txn)
        HistoryLogger.logQuietly(stone: lot, type: .sentToCustomer,
                                  message: "Lot on memo to \(custName)", modelContext: modelContext)
        try modelContext.save()
    }

    /// Add lot to invoice: deducts carats, marks as sold, creates transaction.
    @MainActor
    static func addToInvoice(
        _ lot: Gemstone,
        carats: Double,
        invoice: Invoice,
        modelContext: ModelContext
    ) throws {
        guard lot.isLot else { return }
        guard carats > 0 else {
            throw TransactionError.invalidCaratWeight
        }
        guard carats <= lot.effectiveRemainingCarats else {
            throw TransactionError.lotInsufficientCarats(available: lot.effectiveRemainingCarats, requested: carats)
        }

        let rate = lot.sellPrice
        let amount = rate * Decimal(carats)
        let desc = StoneDescriptionBuilder.buildDescription(for: lot)
        let lockedCost = lot.effectiveAverageCost
        let item = LineItem(
            sku: lot.sku,
            itemDescription: desc,
            carats: carats,
            rate: rate,
            amount: amount,
            kind: .inventory,
            status: .sold,
            isLotLineItem: true,
            lockedCostPerCarat: lockedCost,
            gemstone: lot
        )
        modelContext.insert(item)
        item.invoice = invoice
        lot.effectiveRemainingCarats -= carats

        let custName = invoice.customer?.displayName ?? "Unknown"
        let txn = LotTransaction(
            type: .sold,
            carats: carats,
            pricePerCarat: rate,
            totalPrice: amount,
            lockedCostPerCarat: lockedCost,
            notes: "Sold to \(custName)",
            gemstone: lot
        )
        modelContext.insert(txn)
        lot.lotTransactions.append(txn)
        HistoryLogger.logQuietly(stone: lot, type: .sold,
                                  message: "Lot sold to \(custName)", modelContext: modelContext)
        try modelContext.save()
    }
}
