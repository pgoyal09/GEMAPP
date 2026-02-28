import Foundation
import SwiftData

@Model
final class Memo {
    var status: MemoStatus
    var dateAssigned: Date?
    var dateCompleted: Date?
    var notes: String?
    var createdAt: Date
    var referenceNumber: String?
    
    var customer: Customer?
    
    @Relationship(inverse: \LineItem.memo)
    var lineItems: [LineItem] = []
    
    init(
        status: MemoStatus,
        dateAssigned: Date? = nil,
        dateCompleted: Date? = nil,
        notes: String? = nil,
        createdAt: Date = Date(),
        referenceNumber: String? = nil,
        customer: Customer? = nil
    ) {
        self.status = status
        self.dateAssigned = dateAssigned
        self.dateCompleted = dateCompleted
        self.notes = notes
        self.createdAt = createdAt
        self.referenceNumber = referenceNumber
        self.customer = customer
    }
    
    /// Gemstones on this memo (from line items that have a gemstone)
    var gemstones: [Gemstone] {
        lineItems.compactMap { $0.gemstone }
    }
    
    /// Sum of all line item amounts (for display).
    var totalAmount: Decimal {
        lineItems.reduce(Decimal(0)) { $0 + $1.amount }
    }
    
    /// Line items still open (can be converted to invoice or returned).
    var openLineItems: [LineItem] {
        lineItems.filter { $0.effectiveStatus == .open }
    }

    /// Value of line items still on memo (excludes returned/invoiced).
    var openMemoAmount: Decimal {
        openLineItems.reduce(Decimal(0)) { $0 + $1.amount }
    }

    /// True if any line items are still on memo.
    var hasOpenItems: Bool {
        !openLineItems.isEmpty
    }

    /// True if all line items are resolved (returned or invoiced).
    var isClosed: Bool {
        openLineItems.isEmpty
    }
}

enum MemoStatus: String, Codable, CaseIterable {
    case inStock = "In Stock"
    case onMemo = "On Memo"
    case sold = "Sold"
    case returned = "Returned"
}
