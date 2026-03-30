import Foundation
import SwiftData

@Model
final class Invoice {
    var invoiceDate: Date
    var dueDate: Date?
    var terms: String
    var referenceNumber: String
    var notes: String
    var createdAt: Date
    var status: InvoiceStatus

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

    // MARK: - Computed

    var totalAmount: Decimal {
        lineItems.reduce(Decimal.zero) { $0 + $1.amount }
    }
}
