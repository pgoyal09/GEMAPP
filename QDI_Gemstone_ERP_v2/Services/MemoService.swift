import Foundation
import SwiftData
import os

private let logger = Logger(subsystem: "com.qdi.gemapp", category: "memo")

/// Memo-specific business operations.
enum MemoService {

    /// Return selected items from a memo to stock.
    @MainActor
    static func returnItems(_ items: [LineItem], modelContext: ModelContext) throws {
        var affectedMemos: Set<ObjectIdentifier> = []
        for item in items {
            item.status = .returned
            item.returnedDate = Date()

            if let memo = item.memo {
                affectedMemos.insert(ObjectIdentifier(memo))
            }

            if let stone = item.gemstone {
                let memoRef = item.memo?.referenceNumber ?? "?"
                if item.isLotLineItem {
                    stone.effectiveRemainingCarats += item.carats
                    let txn = LotTransaction(
                        type: .returned,
                        carats: item.carats,
                        pricePerCarat: item.rate,
                        totalPrice: item.amount,
                        notes: "Returned from Memo #\(memoRef)",
                        gemstone: stone
                    )
                    modelContext.insert(txn)
                    stone.lotTransactions.append(txn)
                    HistoryLogger.logQuietly(stone: stone, type: .returnedFromCustomer,
                                              message: "Lot returned from Memo #\(memoRef)", modelContext: modelContext)
                } else {
                    stone.status = .available
                    stone.memo = nil
                    HistoryLogger.logQuietly(stone: stone, type: .returnedFromCustomer,
                                              message: "Returned from Memo #\(memoRef)", modelContext: modelContext)
                }
            }
        }
        try modelContext.save()

        // Auto-close affected memos if all items are resolved
        for item in items {
            if let memo = item.memo {
                checkAndAutoClose(memo: memo, modelContext: modelContext)
            }
        }
    }

    /// Checks if all line items are resolved (sold, returned, or cancelled) and auto-closes the memo.
    @MainActor
    static func checkAndAutoClose(memo: Memo, modelContext: ModelContext) {
        guard !memo.lineItems.isEmpty else { return }
        let allResolved = memo.lineItems.allSatisfy { $0.status == .sold || $0.status == .returned }
        guard allResolved else { return }

        let allReturned = memo.lineItems.allSatisfy { $0.status == .returned }
        if allReturned {
            memo.status = .returned
        } else {
            memo.status = .sold
        }
        memo.dateCompleted = Date()
        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to save memo auto-close: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Convert selected memo line items to a new invoice. Does NOT mark items as sold yet.
    @MainActor
    static func convertToInvoice(
        memo: Memo,
        selectedItems: [LineItem],
        modelContext: ModelContext
    ) throws -> Invoice? {
        guard let customer = memo.customer, !selectedItems.isEmpty else { return nil }

        let ref = ReferenceNumberGenerator.nextInvoiceNumber(modelContext: modelContext)
        let invoice = Invoice(
            terms: "Net 30",
            referenceNumber: ref,
            customer: customer,
            originMemo: memo
        )
        modelContext.insert(invoice)

        for original in selectedItems {
            let copy = LineItem(
                sku: original.sku,
                itemDescription: original.itemDescription,
                carats: original.carats,
                rate: original.rate,
                amount: original.amount,
                kind: original.kind,
                brokeredStoneType: original.brokeredStoneType,
                isLotLineItem: original.isLotLineItem,
                lockedCostPerCarat: original.lockedCostPerCarat,
                gemstone: original.gemstone
            )
            copy.invoice = invoice
            copy.originLineItem = original
            modelContext.insert(copy)
        }

        // Check if memo should auto-close after conversion
        checkAndAutoClose(memo: memo, modelContext: modelContext)

        return invoice
    }

    /// Delete a memo and return all open items to stock.
    @MainActor
    static func deleteMemo(_ memo: Memo, modelContext: ModelContext) throws {
        try returnItems(memo.openLineItems, modelContext: modelContext)
        for item in memo.lineItems {
            modelContext.delete(item)
        }
        modelContext.delete(memo)
        try modelContext.save()
    }
}
