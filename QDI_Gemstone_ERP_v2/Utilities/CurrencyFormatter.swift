import Foundation

extension Decimal {
    /// Formats as USD currency string: "$1,234.56". Falls back to "$0.00".
    var asCurrency: String {
        currencyFormatter.string(from: self as NSDecimalNumber) ?? "$0.00"
    }
}

private let currencyFormatter: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.currencyCode = "USD"
    f.locale = Locale(identifier: "en_US")
    return f
}()
