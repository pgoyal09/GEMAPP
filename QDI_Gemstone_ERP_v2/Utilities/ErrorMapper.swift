import Foundation
import os

/// Maps common SwiftData/Foundation errors to user-friendly strings.
/// Logs the full error via os.Logger; returns a concise message for toast display.
/// All user-facing error strings are scrubbed — raw `localizedDescription` is never shown
/// unless it is short and non-technical.
enum ErrorMapper {
    private static let logger = Logger(subsystem: "com.qualitydiajewels.QDI-Gemstone-ERP", category: "error")

    /// Returns a user-friendly error message and logs the full error.
    static func userMessage(from error: Error) -> String {
        logger.error("Error: \(error.localizedDescription, privacy: .public)")

        let nsError = error as NSError

        // SwiftData / Core Data errors (NSCocoaErrorDomain string comparison for bridging)
        if nsError.domain == "NSCocoaErrorDomain" || nsError.domain == NSCocoaErrorDomain {
            switch nsError.code {
            // Validation
            case 1570:   return "A required field is missing."
            case 1560:   return "Multiple validation errors occurred. Check required fields."
            case 1580:   return "A field value is not valid."

            // Managed object
            case 133000: return "This record could not be found. It may have been deleted."
            case 133020: return "This record was modified elsewhere. Please refresh and try again."
            case 133021: return "A conflict occurred while saving. Please try again."

            // Persistent store
            case 134030: return "The database is unavailable. Please restart the app."
            case 134060: return "The database could not be migrated. Data may need to be re-imported."
            case 134080: return "An incompatible store version was found."
            case 134110: return "Unable to open the database store."
            case 134180: return "The database schema is incompatible. Please reinstall the app."

            // File system
            case NSFileWriteOutOfSpaceError: return "Not enough disk space."
            case NSFileWriteNoPermissionError: return "Permission denied."
            case NSFileNoSuchFileError: return "The file was not found."
            case NSFileReadNoPermissionError: return "Permission denied when reading file."
            case NSFileReadCorruptFileError: return "The file appears to be corrupted."
            case NSFileWriteFileExistsError: return "A file with that name already exists."

            default: break
            }
        }

        // URL / network errors
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorTimedOut: return "The request timed out. Please try again."
            case NSURLErrorNotConnectedToInternet: return "No internet connection."
            case NSURLErrorCannotFindHost: return "Could not reach the server."
            case NSURLErrorNetworkConnectionLost: return "The network connection was lost."
            default: return "A network error occurred. Please check your connection."
            }
        }

        // POSIX errors (e.g. from serial port / RFID)
        if nsError.domain == NSPOSIXErrorDomain {
            switch nsError.code {
            case 13: return "Permission denied. Check system preferences."
            case 16: return "The device is busy. Close other apps using it."
            default: return "A system error occurred. Check Console for details."
            }
        }

        // Generic fallback — scrub long/technical messages
        let desc = error.localizedDescription
        if desc.count > 120 || desc.contains("NSError") || desc.contains("0x") {
            return "An unexpected error occurred. Check Console for details."
        }
        return desc
    }
}
