import Foundation
import SwiftData

/// Logs a history event for a gemstone. Call this when stones are added, sent on memo, returned, or sold.
@MainActor
func logEvent(
    stone: Gemstone,
    type: HistoryEventType,
    message: String,
    modelContext: ModelContext
) {
    let event = HistoryEvent(
        date: Date(),
        eventDescription: message,
        eventType: type,
        gemstone: stone
    )
    modelContext.insert(event)
    
    do {
        try modelContext.save()
    } catch {
        print("HistoryLogger: Failed to save event: \(error)")
    }
}
