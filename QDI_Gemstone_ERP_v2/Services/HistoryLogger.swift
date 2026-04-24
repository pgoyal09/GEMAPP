import Foundation
import SwiftData
import os

private let logger = Logger(subsystem: "com.qualitydiajewels.QDI-Gemstone-ERP", category: "history")

/// Records audit trail events for gemstones. All methods throw on failure.
enum HistoryLogger {

    @MainActor
    static func log(
        stone: Gemstone,
        type: HistoryEventType,
        message: String,
        modelContext: ModelContext
    ) throws {
        let event = HistoryEvent(
            eventDescription: message,
            eventType: type,
            gemstone: stone
        )
        modelContext.insert(event)
        try modelContext.save()
    }

    /// Convenience: logs and swallows errors with a warning.
    @MainActor
    static func logQuietly(
        stone: Gemstone,
        type: HistoryEventType,
        message: String,
        modelContext: ModelContext
    ) {
        do {
            try log(stone: stone, type: type, message: message, modelContext: modelContext)
        } catch {
            logger.warning("Failed to log history event: \(error.localizedDescription, privacy: .public)")
        }
    }
}
