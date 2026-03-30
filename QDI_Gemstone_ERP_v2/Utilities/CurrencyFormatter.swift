import Foundation

extension Decimal {
    /// Formats as USD currency string: "$1,234.56". Falls back to "$0.00".
    var asCurrency: String {
        currencyFormatter.string(from: self as NSDecimalNumber) ?? "$0.00"
    }

    /// Abbreviated currency: "$1.2K", "$3.4M" for large amounts; full format for < $1,000.
    var asCurrencyShort: String {
        let amount = NSDecimalNumber(decimal: self).doubleValue
        switch abs(amount) {
        case 1_000_000...:
            return String(format: "$%.1fM", amount / 1_000_000)
        case 1_000...:
            return String(format: "$%.1fK", amount / 1_000)
        default:
            return asCurrency
        }
    }
}

private let currencyFormatter: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.currencyCode = "USD"
    f.locale = Locale(identifier: "en_US")
    return f
}()
