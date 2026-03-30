import Foundation

enum LineItemStatus: String, Codable, CaseIterable {
    case open = "Open"
    case returned = "Returned"
    case sold = "Sold"
}
