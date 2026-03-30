import Foundation

/// Payment method for invoice payments.
enum PaymentMethod: String, Codable, CaseIterable {
    case wire = "Wire"
    case cheque = "Cheque"
    case cash = "Cash"
    case card = "Card"
}
