import Foundation

enum StoneType: String, Codable, CaseIterable, Identifiable {
    case diamond = "Diamond"
    case emerald = "Emerald"
    case ruby = "Ruby"
    case sapphire = "Sapphire"
    case tanzanite = "Tanzanite"
    case alexandrite = "Alexandrite"
    case amethyst = "Amethyst"
    case aquamarine = "Aquamarine"
    case citrine = "Citrine"
    case garnet = "Garnet"
    case morganite = "Morganite"
    case opal = "Opal"
    case paraiba = "Paraiba"
    case peridot = "Peridot"
    case spinel = "Spinel"
    case topaz = "Topaz"
    case tourmaline = "Tourmaline"
    case tsavorite = "Tsavorite"
    case zircon = "Zircon"
    case other = "Other"

    var id: Self { self }

    var isDiamond: Bool { self == .diamond }

    /// Two-character SKU code.
    var skuCode: String {
        switch self {
        case .diamond:      return "DI"
        case .emerald:      return "EM"
        case .ruby:         return "RU"
        case .sapphire:     return "SA"
        case .tanzanite:    return "TZ"
        case .alexandrite:  return "AL"
        case .amethyst:     return "AM"
        case .aquamarine:   return "AQ"
        case .citrine:      return "CI"
        case .garnet:       return "GA"
        case .morganite:    return "MO"
        case .opal:         return "OP"
        case .paraiba:      return "PA"
        case .peridot:      return "PE"
        case .spinel:       return "SP"
        case .topaz:        return "TO"
        case .tourmaline:   return "TL"
        case .tsavorite:    return "TS"
        case .zircon:       return "ZI"
        case .other:        return "OT"
        }
    }

    /// RapNet gemstone type name (for CSV export).
    var rapNetName: String { rawValue }
}
