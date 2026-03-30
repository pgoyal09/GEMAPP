import Foundation

/// Inventory lifecycle status.
enum GemstoneStatus: String, Codable, CaseIterable {
    case available = "Available"
    case onMemo = "On Memo"
    case sold = "Sold"
    case atLab = "At Lab"
    case reserved = "Reserved"
    case inTransit = "In Transit"
    case consignment = "Consignment"
}
