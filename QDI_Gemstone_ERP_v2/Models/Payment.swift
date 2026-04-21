import Foundation
import SwiftData

@Model
final class Payment {
    var date: Date
    var amount: Decimal
    var method: PaymentMethod
    var referenceNumber: String
    var isVoided: Bool
    var invoice: Invoice?

    init(
        date: Date = Date(),
        amount: Decimal = 0,
        method: PaymentMethod = .wire,
        referenceNumber: String = "",
        invoice: Invoice? = nil
    ) {
        self.date = date
        self.amount = amount
        self.method = method
        self.referenceNumber = referenceNumber
        self.isVoided = false
        self.invoice = invoice
    }
}
