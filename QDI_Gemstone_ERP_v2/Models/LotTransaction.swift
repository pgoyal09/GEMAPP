import Foundation
import SwiftData

/// Ledger entry for a lot stone: tracks every addition, memo-out, return, and sale.
@Model
final class LotTransaction {
    var type: LotTransactionType
    var carats: Double
    var date: Date
    var pricePerCarat: Decimal
    var totalPrice: Decimal
    var lockedCostPerCarat: Decimal?
    var notes: String

    var gemstone: Gemstone?

    init(
        type: LotTransactionType,
        carats: Double,
        date: Date = Date(),
        pricePerCarat: Decimal,
        totalPrice: Decimal,
        lockedCostPerCarat: Decimal? = nil,
        notes: String = "",
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

    // MARK: - Computed

    var profitPerCarat: Decimal? {
        guard type == .sold, let cost = lockedCostPerCarat else { return nil }
        return pricePerCarat - cost
    }

    var totalProfit: Decimal? {
        guard let ppc = profitPerCarat else { return nil }
        return ppc * Decimal(carats)
    }
}
