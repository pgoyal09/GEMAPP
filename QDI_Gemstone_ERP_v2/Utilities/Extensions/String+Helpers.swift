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

    /// Escape a CSV field: wrap in quotes if it contains commas, quotes, or newlines.
    /// Prepends a tab character if the field starts with a formula-injection character
    /// (`=`, `+`, `-`, `@`) to prevent spreadsheet formula injection.
    var csvEscaped: String {
        var value = self
        // Guard against CSV formula injection — tab prefix neutralizes formula interpretation
        if let first = value.first, "=+\u{2d}@".contains(first) {
            value = "\t" + value
        }
        if value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\t") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}
