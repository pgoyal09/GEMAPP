import Foundation

enum HistoryEventType: String, Codable, CaseIterable {
    case dateAdded = "Date Added"
    case sentToCustomer = "Sent to Customer"
    case returnedFromCustomer = "Returned from Customer"
    case sold = "Sold"
    case priceUpdated = "Price Updated"
}
