import Foundation
import SwiftData

@Model
final class ReconciliationRecord {
    var date: Date = Date()
    var matchedCount: Int = 0
    var missingCount: Int = 0
    var unknownCount: Int = 0
    var missingSkus: String = ""

    init(matchedCount: Int, missingCount: Int, unknownCount: Int, missingSkus: String) {
        self.date = Date()
        self.matchedCount = matchedCount
        self.missingCount = missingCount
        self.unknownCount = unknownCount
        self.missingSkus = missingSkus
    }
}
