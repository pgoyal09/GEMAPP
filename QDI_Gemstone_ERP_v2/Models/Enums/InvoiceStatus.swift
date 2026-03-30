import Foundation

enum InvoiceStatus: String, Codable, CaseIterable {
    case draft = "Draft"
    case sent = "Sent"
    case paid = "Paid"
    case void = "Void"
}
