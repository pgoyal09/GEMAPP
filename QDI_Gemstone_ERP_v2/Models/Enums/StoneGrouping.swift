import Foundation

/// How stones are grouped: individual or bulk lot.
/// `.pair` is retained for backward-compatible deserialization only — it is excluded
/// from `allCases` and UI pickers. The migration converts existing pairs → singles.
enum StoneGrouping: String, Codable, Identifiable {
    case single = "S"
    case pair = "P" // Deprecated: kept for deserialization, hidden from UI
    case lot = "L"

    var id: Self { self }

    /// Cases available for UI pickers (excludes deprecated pair).
    static var allCases: [StoneGrouping] { [.single, .lot] }

    var displayName: String {
        switch self {
        case .single, .pair: return "Single"
        case .lot:           return "Lot"
        }
    }

    /// SKU code: "S" or "L" (pair maps to "S")
    var skuCode: String {
        switch self {
        case .single, .pair: return "S"
        case .lot:           return "L"
        }
    }
}
