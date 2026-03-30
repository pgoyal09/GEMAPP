import Foundation

/// Distinguishes the three types of line items on memos and invoices.
enum LineItemKind: String, Codable, CaseIterable {
    /// Linked to an inventory Gemstone.
    case inventory = "Inventory"
    /// Manually entered stone not in inventory (brokered/consigned from third party).
    case brokered = "Brokered"
    /// Service fee or miscellaneous charge (no carats).
    case service = "Service"
}
