import Foundation
import SwiftData

@Model
final class LineItem {
    var sku: String
    var itemDescription: String
    var carats: Double
    var rate: Decimal
    var amount: Decimal
    var kind: LineItemKind
    var status: LineItemStatus

    /// Per-line discount amount (flat dollar amount subtracted from this line).
    var discount: Decimal

    /// Stone type label for brokered lines (no linked gemstone).
    var brokeredStoneType: String

    /// True when this line represents a partial lot allocation.
    var isLotLineItem: Bool
    /// Average cost per carat locked at sale time (for P&L on lot items).
    var lockedCostPerCarat: Decimal?

    var returnedDate: Date?
    var soldDate: Date?

    // MARK: - Relationships

    @Relationship(deleteRule: .nullify)
    var gemstone: Gemstone?
    var invoice: Invoice?
    var memo: Memo?
    /// When this line was copied from a memo to an invoice, points to the original memo line.
    @Relationship(deleteRule: .nullify)
    var originLineItem: LineItem?

    init(
        sku: String = "",
        itemDescription: String = "",
        carats: Double = 0,
        rate: Decimal = 0,
        amount: Decimal = 0,
        kind: LineItemKind = .inventory,
        status: LineItemStatus = .open,
        discount: Decimal = 0,
        brokeredStoneType: String = "",
        isLotLineItem: Bool = false,
        lockedCostPerCarat: Decimal? = nil,
        gemstone: Gemstone? = nil
    ) {
        self.sku = sku
        self.itemDescription = itemDescription
        self.carats = carats
        self.rate = rate
        self.amount = amount
        self.kind = kind
        self.status = status
        self.discount = discount
        self.brokeredStoneType = brokeredStoneType
        self.isLotLineItem = isLotLineItem
        self.lockedCostPerCarat = lockedCostPerCarat
        self.gemstone = gemstone
    }

    // MARK: - Display Helpers

    var displaySku: String {
        if let g = gemstone { return g.sku }
        return kind == .service ? "" : (sku.isEmpty ? "—" : sku)
    }

    var displayName: String {
        if let g = gemstone {
            return "\(g.stoneType.rawValue) \(g.color) \(g.clarity) \(g.cut)"
        }
        return itemDescription.isEmpty ? "Unknown Item" : itemDescription
    }

    var stoneTypeDisplay: String {
        if let g = gemstone { return g.stoneType.rawValue }
        if !brokeredStoneType.isEmpty { return brokeredStoneType }
        return kind == .service ? "Service" : "—"
    }

    var displayCarats: String {
        kind == .service ? "—" : String(format: "%.2f", carats)
    }

    /// Amount after per-line discount.
    var netAmount: Decimal {
        max(amount - discount, 0)
    }
}
