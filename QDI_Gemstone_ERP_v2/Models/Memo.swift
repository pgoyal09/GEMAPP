import Foundation
import SwiftData

@Model
final class Memo {
    var status: MemoStatus
    var dateAssigned: Date?
    var dateCompleted: Date?
    var notes: String
    var createdAt: Date
    @Attribute(.unique)
    var referenceNumber: String

    @Relationship
    var customer: Customer?

    @Relationship(deleteRule: .nullify, inverse: \Invoice.originMemo)
    var invoicesFromMemo: [Invoice] = []

    @Relationship(deleteRule: .cascade, inverse: \LineItem.memo)
    var lineItems: [LineItem] = []

    init(
        status: MemoStatus = .onMemo,
        dateAssigned: Date? = nil,
        dateCompleted: Date? = nil,
        notes: String = "",
        createdAt: Date = Date(),
        referenceNumber: String = "",
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

    // MARK: - Computed

    var totalAmount: Decimal {
        lineItems.reduce(Decimal.zero) { $0 + $1.amount }
    }

    var openLineItems: [LineItem] {
        lineItems.filter { $0.status == .open }
    }

    var openMemoAmount: Decimal {
        openLineItems.reduce(Decimal.zero) { $0 + $1.amount }
    }

    var isClosed: Bool {
        lineItems.allSatisfy { $0.status != .open }
    }

    /// Days since creation.
    var ageInDays: Int {
        Calendar.current.dateComponents([.day], from: createdAt, to: Date()).day ?? 0
    }
}
