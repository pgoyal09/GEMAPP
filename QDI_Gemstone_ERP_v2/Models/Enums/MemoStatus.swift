import Foundation

enum MemoStatus: String, Codable, CaseIterable {
    case onMemo = "On Memo"
    case returned = "Returned"
    case sold = "Sold"
}
