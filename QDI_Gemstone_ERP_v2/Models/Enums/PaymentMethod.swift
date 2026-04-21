import Foundation

/// Payment method for invoice payments.
enum PaymentMethod: String, Codable, CaseIterable {
    case wire = "Wire"
    case cheque = "Check"
    case cash = "Cash"
    case card = "Card"
}
