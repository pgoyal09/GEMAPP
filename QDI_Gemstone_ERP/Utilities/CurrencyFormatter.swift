import Foundation

extension Decimal {
    /// Format as USD currency string (e.g. "$1,234.56"). Shared across the entire app.
    var asCurrency: String {
        CurrencyHelper.shared.string(from: self as NSDecimalNumber) ?? "$0.00"
    }
}

enum CurrencyHelper {
    static let shared: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        return f
    }()
}
