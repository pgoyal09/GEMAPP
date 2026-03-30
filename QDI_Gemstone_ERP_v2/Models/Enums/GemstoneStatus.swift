import Foundation

/// Inventory lifecycle status.
enum GemstoneStatus: String, Codable, CaseIterable {
    case available = "Available"
    case onMemo = "On Memo"
    case sold = "Sold"
}
