import Foundation
import SwiftData

enum LotTransactionType: String, Codable, CaseIterable {
    case added = "Added"
    case sold = "Sold"
    case returned = "Returned"
    case onMemo = "On Memo"
}

/// Ledger entry for a lot stone: tracks every add, memo-out, return, and sale.
@Model
final class LotTransaction {
    var type: LotTransactionType
    var carats: Double
    var date: Date
    /// Per-carat price: sell price for sales/memo, cost per carat for additions.
    var pricePerCarat: Decimal
    var totalPrice: Decimal
    /// Average cost locked at time of sale (for profit calculation).
    var lockedCostPerCarat: Decimal?
    var notes: String?

    var gemstone: Gemstone?

    init(
        type: LotTransactionType,
        carats: Double,
        date: Date = Date(),
        pricePerCarat: Decimal,
        totalPrice: Decimal,
        lockedCostPerCarat: Decimal? = nil,
        notes: String? = nil,
        gemstone: Gemstone? = nil
    ) {
        self.type = type
        self.carats = carats
        self.date = date
        self.pricePerCarat = pricePerCarat
        self.totalPrice = totalPrice
        self.lockedCostPerCarat = lockedCostPerCarat
        self.notes = notes
        self.gemstone = gemstone
    }

    /// Profit per carat for a sold transaction. Nil for non-sale types.
    var profitPerCarat: Decimal? {
        guard type == .sold, let cost = lockedCostPerCarat else { return nil }
        return pricePerCarat - cost
    }

    /// Total profit for a sold transaction. Nil for non-sale types.
    var totalProfit: Decimal? {
        guard let ppc = profitPerCarat else { return nil }
        return ppc * Decimal(carats)
    }
}
