import Foundation
import SwiftData

@Model
final class PaymentReminder {
    var date: Date = Date()
    var customerName: String = ""
    var invoiceReferences: String = ""
    var amount: Decimal = 0
    var sent: Bool = false
    var method: String = "memo"
    var createdAt: Date = Date()

    init(customerName: String, invoiceReferences: String, amount: Decimal = 0, method: String = "memo") {
        self.date = Date()
        self.customerName = customerName
        self.invoiceReferences = invoiceReferences
        self.amount = amount
        self.method = method
        self.sent = false
        self.createdAt = Date()
    }
}
