import Foundation

enum LotTransactionType: String, Codable, CaseIterable {
    case added = "Added"
    case sold = "Sold"
    case returned = "Returned"
    case onMemo = "On Memo"

    var displayIcon: String {
        switch self {
        case .added:    return "plus.circle.fill"
        case .sold:     return "checkmark.circle.fill"
        case .returned: return "arrow.uturn.backward.circle.fill"
        case .onMemo:   return "doc.text.fill"
        }
    }
}
