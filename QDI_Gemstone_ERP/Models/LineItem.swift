import Foundation
#if canImport(SwiftData)
import SwiftData
#endif

enum LineItemStatus: String, Codable, CaseIterable {
    case open = "Open"
    case returned = "Returned"
    case sold = "Sold"
}

#if canImport(SwiftData)
@Model
#endif
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
    
    /// Flags for "Hybrid" types
    var isService: Bool
    
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
        self.status = status
        self.returnedDate = returnedDate
        self.soldDate = soldDate
    }
    
    /// Use in UI; existing items without status count as .open.
    var effectiveStatus: LineItemStatus {
        status ?? .open
    }
    
    // MARK: - Safe Display Helpers
    
    var isCustomLine: Bool { gemstone == nil }
    
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
    
    var displayCarats: String {
        if isService { return "—" }
        return String(format: "%.2f", carats)
    }
    
    var displayRate: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: rate as NSDecimalNumber) ?? "$0.00"
    }
    
    var displayAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: amount as NSDecimalNumber) ?? "$0.00"
    }
}