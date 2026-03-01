import Foundation
import SwiftData

enum InvoiceStatus: String, Codable, CaseIterable {
    case draft = "Draft"
    case sent = "Sent"
    case paid = "Paid"
    case void = "Void"
}

@Model
final class Invoice {
    var invoiceDate: Date
    var dueDate: Date?
    var terms: String?
    var referenceNumber: String?
    var notes: String?
    var createdAt: Date
    /// Defaults to .sent when nil (e.g. for invoices created before status existed).
    var status: InvoiceStatus?
    
    var customer: Customer?
    
    /// When non-nil, this invoice was created from a memo; removing a line restores the stone to that memo (.onMemo).
    var originMemo: Memo?
    
    @Relationship(inverse: \LineItem.invoice)
    var lineItems: [LineItem] = []
    
    init(
        invoiceDate: Date = Date(),
        dueDate: Date? = nil,
        terms: String? = nil,
        referenceNumber: String? = nil,
        notes: String? = nil,
        createdAt: Date = Date(),
        status: InvoiceStatus? = .sent,
        customer: Customer? = nil,
        originMemo: Memo? = nil
    ) {
        self.invoiceDate = invoiceDate
        self.dueDate = dueDate
        self.terms = terms
        self.referenceNumber = referenceNumber
        self.notes = notes
        self.createdAt = createdAt
        self.status = status
        self.customer = customer
        self.originMemo = originMemo
    }
    
    var effectiveStatus: InvoiceStatus { status ?? .sent }

    var totalAmount: Decimal {
        lineItems.reduce(Decimal(0)) { $0 + $1.amount }
    }

    var customerDisplayName: String {
        customer?.displayName ?? ""
    }
}
