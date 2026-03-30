import Foundation
import SwiftData

@Model
final class HistoryEvent {
    var date: Date
    var eventDescription: String
    var eventType: HistoryEventType

    var gemstone: Gemstone?

    init(
        date: Date = Date(),
        eventDescription: String,
        eventType: HistoryEventType,
        gemstone: Gemstone? = nil
    ) {
        self.date = date
        self.eventDescription = eventDescription
        self.eventType = eventType
        self.gemstone = gemstone
    }
}
