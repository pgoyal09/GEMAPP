import Foundation

extension Date {
    /// Abbreviated date string (e.g., "Mar 30, 2026").
    var shortFormatted: String {
        formatted(date: .abbreviated, time: .omitted)
    }

    /// Month + day only (e.g., "Mar 30").
    var monthDay: String {
        formatted(.dateTime.month(.abbreviated).day())
    }

    /// Date + time without seconds (e.g., "Mar 30, 2026 at 2:15 PM").
    var dateTimeFormatted: String {
        formatted(.dateTime.year().month().day().hour().minute())
    }
}
