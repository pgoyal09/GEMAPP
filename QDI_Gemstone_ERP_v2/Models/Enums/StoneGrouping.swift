import Foundation

/// How stones are grouped: individual, pair, or bulk lot.
enum StoneGrouping: String, Codable, CaseIterable, Identifiable {
    case single = "S"
    case pair = "P"
    case lot = "L"

    var id: Self { self }

    var displayName: String {
        switch self {
        case .single: return "Single"
        case .pair:   return "Pair"
        case .lot:    return "Lot"
        }
    }

    /// SKU code: "S", "P", or "L"
    var skuCode: String { rawValue }
}
