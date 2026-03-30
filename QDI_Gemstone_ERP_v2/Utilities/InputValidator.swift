import Foundation

/// Centralized input validation for form fields across the app.
enum InputValidator {

    // MARK: - Limits

    static let maxPrice: Decimal = 99_999_999
    static let maxSKULength = 50
    static let maxShortString = 200
    static let maxCustomerName = 100
    static let maxCompanyName = 200
    static let maxLineItemsPerDocument = 500

    // MARK: - Numeric Validation

    static func validateCaratWeight(_ value: Double) -> String? {
        if value.isNaN || value.isInfinite {
            return "Carat weight is invalid."
        }
        if value < 0 {
            return "Carat weight cannot be negative."
        }
        return nil
    }

    static func validatePrice(_ value: Decimal, field: String) -> String? {
        if value < 0 {
            return "\(field) cannot be negative."
        }
        if value > maxPrice {
            return "\(field) exceeds maximum (\(maxPrice))."
        }
        return nil
    }

    static func validatePositiveAmount(_ value: Decimal, field: String) -> String? {
        if value < 0 {
            return "\(field) cannot be negative."
        }
        if value > maxPrice {
            return "\(field) exceeds maximum (\(maxPrice))."
        }
        return nil
    }

    // MARK: - String Validation

    static func validateSKU(_ value: String) -> String? {
        if value.count > maxSKULength {
            return "SKU must be \(maxSKULength) characters or less."
        }
        if value.contains(where: { $0.isNewline || $0.asciiValue.map({ $0 < 32 }) == true }) {
            return "SKU contains invalid characters."
        }
        return nil
    }

    static func validateStringField(_ value: String, field: String, maxLength: Int = maxShortString) -> String? {
        if value.count > maxLength {
            return "\(field) must be \(maxLength) characters or less."
        }
        return nil
    }

    // MARK: - Customer Validation

    static func validateEmail(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let pattern = #"^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#
        if trimmed.range(of: pattern, options: .regularExpression) == nil {
            return "Invalid email format."
        }
        return nil
    }

    static func validatePhone(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let digits = trimmed.filter { $0.isNumber }
        if digits.count < 7 || digits.count > 15 {
            return "Phone number must be 7–15 digits."
        }
        let allowed = CharacterSet(charactersIn: "0123456789+()-. ")
        if trimmed.unicodeScalars.contains(where: { !allowed.contains($0) }) {
            return "Phone contains invalid characters."
        }
        return nil
    }

    // MARK: - Document Validation

    static func validateLineItemCount(_ count: Int) -> String? {
        if count >= maxLineItemsPerDocument {
            return "Maximum of \(maxLineItemsPerDocument) line items per document."
        }
        return nil
    }
}
