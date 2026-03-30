import Foundation

// MARK: - EPC Canonical Contract

/// Normalizes raw RFID payloads into a stable 24-character (12-byte) uppercase hex EPC string.
/// The canonical form is the single source of truth for EPC comparisons and database lookups.
enum EPCanonical {

    /// E2 80 header present on standard UHF Gen2 tags.
    static let markerPrefix: [UInt8] = [0xE2, 0x80]

    /// Canonical EPC is always 12 bytes.
    static let canonicalByteCount = 12

    /// Hex string length for the canonical form (12 bytes * 2 = 24 chars).
    static let canonicalHexCount = canonicalByteCount * 2

    // MARK: - Public API

    /// Normalize an already-hex EPC string to canonical form.
    /// Returns nil if the input does not contain exactly 24 hex digits after filtering.
    static func normalize(_ input: String) -> String? {
        let filtered = input
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .filter(\.isHexDigit)
        guard filtered.count == canonicalHexCount else { return nil }
        return filtered
    }

    /// Quick validity check.
    static func isValid(_ input: String) -> Bool {
        normalize(input) != nil
    }

    /// Convert a raw hex string (possibly longer than 24 chars) to canonical form.
    /// Tries marker-based extraction first, then falls back to tail extraction and exact-length match.
    static func canonicalHex(fromRawHex rawHex: String) -> String? {
        let compact = rawHex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .filter(\.isHexDigit)

        guard !compact.isEmpty else { return nil }
        guard let bytes = bytes(fromHex: compact), !bytes.isEmpty else { return nil }

        if let candidate = canonicalHex(fromPayload: bytes) {
            return candidate
        }

        return normalize(compact)
    }

    /// Extract canonical EPC from a raw byte payload (e.g. directly from the reader frame).
    /// Looks for the E2 80 marker prefix; falls back to the last 12 bytes.
    static func canonicalHex(fromPayload payload: [UInt8]) -> String? {
        guard payload.count >= 2 else { return nil }

        // Scan for the E2 80 marker and grab up to 12 bytes starting there.
        for i in 0..<(payload.count - 1) where payload[i] == markerPrefix[0] && payload[i + 1] == markerPrefix[1] {
            let end = min(i + canonicalByteCount, payload.count)
            let chunk = Array(payload[i..<end])
            let hex = hexString(chunk)
            if let normalized = normalize(hex) {
                return normalized
            }
        }

        // Fallback: take the last canonicalByteCount bytes.
        let fallbackStart = max(0, payload.count - canonicalByteCount)
        let fallbackHex = hexString(Array(payload[fallbackStart...]))
        return normalize(fallbackHex)
    }

    // MARK: - Helpers

    /// Decode a hex string to bytes. Returns nil if the string has odd length or non-hex characters.
    static func bytes(fromHex hex: String) -> [UInt8]? {
        guard hex.count.isMultiple(of: 2) else { return nil }
        var output: [UInt8] = []
        output.reserveCapacity(hex.count / 2)

        var idx = hex.startIndex
        while idx < hex.endIndex {
            let next = hex.index(idx, offsetBy: 2)
            let pair = String(hex[idx..<next])
            guard let byte = UInt8(pair, radix: 16) else { return nil }
            output.append(byte)
            idx = next
        }

        return output
    }

    /// Encode bytes to an uppercase hex string without separators.
    static func hexString(_ bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02X", $0) }.joined()
    }
}
