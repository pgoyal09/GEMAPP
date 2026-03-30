import Foundation

enum StoneType: String, Codable, CaseIterable, Identifiable {
    case diamond = "Diamond"
    case emerald = "Emerald"
    case ruby = "Ruby"
    case sapphire = "Sapphire"
    case tanzanite = "Tanzanite"

    var id: Self { self }

    /// Two-character SKU code.
    var skuCode: String {
        switch self {
        case .diamond:   return "DI"
        case .emerald:   return "EM"
        case .ruby:      return "RU"
        case .sapphire:  return "SA"
        case .tanzanite: return "TZ"
        }
    }
}
