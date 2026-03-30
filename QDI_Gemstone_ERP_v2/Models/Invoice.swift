import Foundation
import SwiftData

@Model
final class Invoice {
    var invoiceDate: Date
    var dueDate: Date?
    var terms: String
    @Attribute(.unique)
    var referenceNumber: String
    var notes: String
    var createdAt: Date
    var status: InvoiceStatus

    /// Invoice-level discount amount (flat dollar amount).
    var discountAmount: Decimal
    /// Tax rate as a percentage (e.g. 8.5 for 8.5%).
    var taxRate: Decimal

    @Relationship
    var customer: Customer?
    /// When non-nil, this invoice was created by converting items from a memo.
    @Relationship(deleteRule: .nullify)
    var originMemo: Memo?

    @Relationship(deleteRule: .cascade, inverse: \LineItem.invoice)
    var lineItems: [LineItem] = []

    init(
        invoiceDate: Date = Date(),
        dueDate: Date? = nil,
        terms: String = "Net 30",
        referenceNumber: String = "",
        notes: String = "",
        createdAt: Date = Date(),
        status: InvoiceStatus = .sent,
        customer: Customer? = nil,
        originMemo: Memo? = nil,
        discountAmount: Decimal = 0,
        taxRate: Decimal = 0
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
        self.discountAmount = discountAmount
        self.taxRate = taxRate
    }

    // MARK: - Computed

    /// Sum of all line item amounts before any discount or tax.
    var totalBeforeDiscount: Decimal {
        lineItems.reduce(Decimal.zero) { $0 + $1.amount }
    }

    /// Subtotal after discount.
    var subtotalAfterDiscount: Decimal {
        max(totalBeforeDiscount - discountAmount, 0)
    }

    /// Tax computed on the discounted subtotal.
    var taxAmount: Decimal {
        guard taxRate > 0 else { return 0 }
        return subtotalAfterDiscount * taxRate / 100
    }

    /// Grand total: subtotal after discount + tax.
    var grandTotal: Decimal {
        subtotalAfterDiscount + taxAmount
    }

    /// Legacy accessor — returns grandTotal for backward compatibility.
    var totalAmount: Decimal { grandTotal }
}
