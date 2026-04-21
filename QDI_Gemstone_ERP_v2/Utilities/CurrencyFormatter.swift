import Foundation

extension Decimal {
    /// Formats as USD currency string: "$1,234.56". Falls back to "$0.00".
    var asCurrency: String {
        CurrencyFormatterCache.shared.formatter(for: .usd).string(from: self as NSDecimalNumber) ?? "$0.00"
    }

    /// Formats in the given currency: e.g. "฿41,250.00" for THB.
    func asCurrency(_ currency: CurrencyType) -> String {
        CurrencyFormatterCache.shared.formatter(for: currency).string(from: self as NSDecimalNumber)
            ?? "\(currency.symbol)0.00"
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

    /// Abbreviated currency in the given currency type.
    func asCurrencyShort(_ currency: CurrencyType) -> String {
        let amount = NSDecimalNumber(decimal: self).doubleValue
        let sym = currency.symbol
        switch abs(amount) {
        case 1_000_000...:
            return String(format: "\(sym)%.1fM", amount / 1_000_000)
        case 1_000...:
            return String(format: "\(sym)%.1fK", amount / 1_000)
        default:
            return asCurrency(currency)
        }
    }
}

// MARK: - Formatter Cache

/// Thread-safe cache of NumberFormatters keyed by CurrencyType.
/// Avoids recreating formatters on every call.
final class CurrencyFormatterCache: @unchecked Sendable {
    static let shared = CurrencyFormatterCache()
    private var formatters: [CurrencyType: NumberFormatter] = [:]
    private let lock = NSLock()

    func formatter(for currency: CurrencyType) -> NumberFormatter {
        lock.lock()
        defer { lock.unlock() }
        if let cached = formatters[currency] { return cached }
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = currency.rawValue
        // Use locale matching for proper symbol placement; fall back to en_US for USD
        switch currency {
        case .usd: f.locale = Locale(identifier: "en_US")
        case .inr: f.locale = Locale(identifier: "en_IN")
        case .eur: f.locale = Locale(identifier: "de_DE")
        case .gbp: f.locale = Locale(identifier: "en_GB")
        case .aed: f.locale = Locale(identifier: "ar_AE")
        case .thb: f.locale = Locale(identifier: "th_TH")
        case .hkd: f.locale = Locale(identifier: "en_HK")
        case .chf: f.locale = Locale(identifier: "de_CH")
        }
        formatters[currency] = f
        return f
    }
}
