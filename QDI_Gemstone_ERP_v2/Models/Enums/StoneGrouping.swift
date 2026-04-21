import Foundation

/// How stones are grouped: individual, matched pair, or bulk lot.
enum StoneGrouping: String, Codable, Identifiable {
    case single = "S"
    case pair = "P"
    case lot = "L"

    var id: Self { self }

    static var allCases: [StoneGrouping] { [.single, .pair, .lot] }

    var displayName: String {
        switch self {
        case .single: return "Single"
        case .pair:   return "Pair"
        case .lot:    return "Lot"
        }
    }

    /// SKU code: "S", "P", or "L"
    var skuCode: String {
        switch self {
        case .single: return "S"
        case .pair:   return "P"
        case .lot:    return "L"
        }
    }
}
