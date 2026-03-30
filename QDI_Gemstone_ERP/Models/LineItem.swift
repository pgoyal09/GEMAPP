import Foundation
import SwiftData

enum LineItemStatus: String, Codable, CaseIterable {
    case open = "Open"
    case returned = "Returned"
    case sold = "Sold"
}

@Model
final class LineItem {
    var sku: String
    var itemDescription: String
    var carats: Double
    var rate: Decimal
    var amount: Decimal
    
    // Relationships
    var gemstone: Gemstone?
    var invoice: Invoice?
    var memo: Memo?
    /// When non-nil, this line item is a copy on an invoice converted from a memo; the original is on the memo. Mark original (and stone) sold when invoice is saved.
    var originLineItem: LineItem?
    
    /// Flags for "Hybrid" types
    var isService: Bool

    /// Stone type label for manually-entered (brokered) lines with no linked gemstone.
    var brokeredStoneType: String?

    /// True when this line item represents a partial lot allocation (carats from a lot stone).
    var isLotLineItem: Bool

    /// Average cost per carat locked at the time this lot line item was sold (for P&L).
    var lockedCostPerCarat: Decimal?
    
    /// Lifecycle: open (on memo), returned (back to stock), sold (converted to invoice). Default .open.
    var status: LineItemStatus?
    var returnedDate: Date?
    var soldDate: Date?
    
    init(
        sku: String = "",
        itemDescription: String,
        carats: Double = 0,
        rate: Decimal,
        amount: Decimal,
        gemstone: Gemstone? = nil,
        isService: Bool = false,
        brokeredStoneType: String? = nil,
        isLotLineItem: Bool = false,
        lockedCostPerCarat: Decimal? = nil,
        status: LineItemStatus = .open,
        returnedDate: Date? = nil,
        soldDate: Date? = nil
    ) {
        self.sku = sku
        self.itemDescription = itemDescription
        self.carats = carats
        self.rate = rate
        self.amount = amount
        self.gemstone = gemstone
        self.isService = isService
        self.brokeredStoneType = brokeredStoneType
        self.isLotLineItem = isLotLineItem
        self.lockedCostPerCarat = lockedCostPerCarat
        self.status = status
        self.returnedDate = returnedDate
        self.soldDate = soldDate
    }
    
    /// Use in UI; existing items without status count as .open.
    var effectiveStatus: LineItemStatus {
        status ?? .open
    }
    
    // MARK: - Safe Display Helpers
    
    var displayName: String {
        // Priority 1: Linked Gemstone (if it exists)
        if let g = gemstone {
            return "\(g.stoneType.rawValue) \(g.color) \(g.clarity) \(g.cut)"
        }
        // Priority 2: Manual Description (fallback)
        if !itemDescription.isEmpty {
            return itemDescription
        }
        return "Unknown Item"
    }
    
    var displaySku: String {
        if let g = gemstone { return g.sku }
        return isService ? "" : (sku.isEmpty ? "—" : sku)
    }
    
    /// Stone type for column display: gemstone type, brokered type, "Service", or "—".
    var stoneTypeDisplay: String {
        if let g = gemstone { return g.stoneType.rawValue }
        if let b = brokeredStoneType, !b.isEmpty { return b }
        return isService ? "Service" : "—"
    }
    
    var displayCarats: String {
        if isService { return "—" }
        return String(format: "%.2f", carats)
    }
    
    var displayRate: String {
        rate.asCurrency
    }
    
    var displayAmount: String {
        amount.asCurrency
    }
}