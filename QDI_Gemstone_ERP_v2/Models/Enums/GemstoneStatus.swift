import Foundation

/// Inventory lifecycle status.
/// Primary flow: available → onMemo → sold (or available → sold via direct invoice).
/// Edge states (atLab, reserved, inTransit, consignment) block memo/invoice operations.
/// To return an edge-state stone to the sales pipeline, change its status to "Available"
/// via the stone detail form or bulk edit.
enum GemstoneStatus: String, Codable, CaseIterable {
    case available = "Available"
    case onMemo = "On Memo"
    case sold = "Sold"
    case atLab = "At Lab"
    case reserved = "Reserved"
    case inTransit = "In Transit"
    case consignment = "Consignment"
}
