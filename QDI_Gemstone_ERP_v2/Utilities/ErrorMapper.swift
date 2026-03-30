import Foundation
import os

/// Maps common SwiftData/Foundation errors to user-friendly strings.
/// Logs the full error via os.Logger; returns a concise message for toast display.
enum ErrorMapper {
    private static let logger = Logger(subsystem: "com.qualitydiajewels.QDI-Gemstone-ERP", category: "error")

    /// Returns a user-friendly error message and logs the full error.
    static func userMessage(from error: Error) -> String {
        logger.error("Error: \(error.localizedDescription, privacy: .public)")

        let nsError = error as NSError

        // SwiftData / Core Data errors
        if nsError.domain == "NSCocoaErrorDomain" {
            switch nsError.code {
            case 133021: return "A conflict occurred while saving. Please try again."
            case 134030: return "The database is unavailable. Please restart the app."
            case 134110: return "Unable to open the database store."
            case 1570:   return "A required field is missing."
            default: break
            }
        }

        // File system errors
        if nsError.domain == NSCocoaErrorDomain {
            switch nsError.code {
            case NSFileWriteOutOfSpaceError: return "Not enough disk space."
            case NSFileWriteNoPermissionError: return "Permission denied."
            default: break
            }
        }

        // Generic fallback
        let desc = error.localizedDescription
        if desc.count > 120 {
            return "An unexpected error occurred. Check Console for details."
        }
        return desc
    }
}
