import Foundation

/// Supported currencies for multi-currency pricing display.
enum CurrencyType: String, Codable, CaseIterable {
    case usd = "USD"
    case inr = "INR"
    case eur = "EUR"
    case gbp = "GBP"
    case aed = "AED"

    var symbol: String {
        switch self {
        case .usd: return "$"
        case .inr: return "\u{20B9}"
        case .eur: return "\u{20AC}"
        case .gbp: return "\u{00A3}"
        case .aed: return "AED"
        }
    }
}
