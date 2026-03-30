import Foundation

extension String {
    /// Returns nil if the string is empty or contains only whitespace.
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Trimmed version of the string.
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
