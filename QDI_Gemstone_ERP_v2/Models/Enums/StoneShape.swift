import Foundation

/// Common stone shapes for pickers and SKU generation.
/// The shape field on Gemstone remains a String for flexibility (custom shapes),
/// but this enum provides the standard options and SKU codes.
enum StoneShape: String, CaseIterable, Identifiable {
    case round = "Round"
    case oval = "Oval"
    case cushion = "Cushion"
    case pear = "Pear"
    case emeraldCut = "Emerald"
    case princess = "Princess"
    case radiant = "Radiant"
    case marquise = "Marquise"
    case heart = "Heart"
    case asscher = "Asscher"
    case cabochon = "Cabochon"
    case other = "Other"

    var id: Self { self }

    var skuCode: String {
        switch self {
        case .round:      return "RD"
        case .oval:       return "OV"
        case .cushion:    return "CU"
        case .pear:       return "PE"
        case .emeraldCut: return "EM"
        case .princess:   return "PR"
        case .radiant:    return "RA"
        case .marquise:   return "MQ"
        case .heart:      return "HE"
        case .asscher:    return "AS"
        case .cabochon:   return "CB"
        case .other:      return "OT"
        }
    }

    /// All shape names for autocomplete.
    static var allNames: [String] {
        allCases.map(\.rawValue)
    }

    /// Find a shape from a display string (case-insensitive).
    static func from(_ string: String) -> StoneShape? {
        allCases.first { $0.rawValue.caseInsensitiveCompare(string) == .orderedSame }
    }

    /// SKU code from a shape string. Falls back to "OT" for unrecognized shapes.
    static func skuCode(from shapeString: String) -> String {
        Self.from(shapeString)?.skuCode ?? "OT"
    }
}
