import Foundation

/// Builds line item descriptions from stone characteristics.
enum StoneDescriptionBuilder {

    static func buildDescription(for stone: Gemstone) -> String {
        stone.stoneType == .diamond
            ? buildDiamondDescription(for: stone)
            : buildNonDiamondDescription(for: stone)
    }

    // MARK: - Diamond

    private static func buildDiamondDescription(for stone: Gemstone) -> String {
        let color = stone.color.trimmedOrNil
        let clarity = stone.clarity.trimmedOrNil
        let caratStr = formatNumber(stone.caratWeight)

        if stone.isLot {
            let size = stone.size?.trimmedOrNil
            return [color, size, clarity].compactMap { $0 }.joined(separator: " ")
        }

        let cut = stone.cut.trimmedOrNil
        let polish = stone.polish.trimmedOrNil
        let symmetry = stone.symmetry.trimmedOrNil
        let fluorescence = stone.fluorescence.trimmedOrNil

        let parts = [caratStr, color, clarity, cut, polish, symmetry, fluorescence].compactMap { $0 }
        var result = parts.joined(separator: " ")

        if stone.hasCert {
            let certParts = [stone.certLab.trimmedOrNil, stone.certNo.trimmedOrNil].compactMap { $0 }
            if !certParts.isEmpty {
                result += "\n" + certParts.joined(separator: " ")
            }
        }
        return result
    }

    // MARK: - Non-Diamond

    private static func buildNonDiamondDescription(for stone: Gemstone) -> String {
        let shape = stone.shape.trimmedOrNil ?? stone.cut.trimmedOrNil

        if stone.isLot {
            var parts: [String] = []
            if let s = shape { parts.append(s) }
            parts.append(contentsOf: formatDimensionCompact(l: stone.length, w: stone.width))
            if let q = stone.quality?.trimmedOrNil { parts.append(q) }
            return parts.joined(separator: " ")
        }

        var topParts: [String] = []
        if stone.hasCert { topParts.append("Certified") }
        if let t = stone.treatment.trimmedOrNil { topParts.append(t) }
        topParts.append(stone.stoneType.rawValue)
        if let s = shape { topParts.append(s) }
        topParts.append(stone.grouping == .pair ? "Pair" : "Single")

        var lines = [topParts.joined(separator: " ")]

        var bottomParts: [String] = []
        if let l = stone.length, let w = stone.width, let h = stone.height {
            bottomParts.append(formatDimensions(l: l, w: w, h: h))
        }
        if let lab = stone.certLab.trimmedOrNil { bottomParts.append(lab) }
        if let no = stone.certNo.trimmedOrNil { bottomParts.append(no) }
        if !bottomParts.isEmpty { lines.append(bottomParts.joined(separator: " ")) }

        return lines.joined(separator: "\n")
    }

    // MARK: - Helpers

    private static func formatNumber(_ v: Double) -> String? {
        let s = v.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(v))" : "\(v)"
        return s == "0" ? nil : s
    }

    private static func formatDimensions(l: Double, w: Double, h: Double) -> String {
        let fmt: (Double) -> String = { v in
            let s = "\(v)"
            return s.hasSuffix(".0") ? String(s.dropLast(2)) : s
        }
        return "\(fmt(l)) x \(fmt(w)) x \(fmt(h)) mm"
    }

    private static func formatDimensionCompact(l: Double?, w: Double?) -> [String] {
        let fmt: (Double) -> String = { v in
            let s = "\(v)"
            return s.hasSuffix(".0") ? String(s.dropLast(2)) : s
        }
        if let l, let w { return ["(\(fmt(l))x\(fmt(w))mm)"] }
        if let l { return ["(\(fmt(l))mm)"] }
        if let w { return ["(\(fmt(w))mm)"] }
        return []
    }
}

// MARK: - String Helpers

private extension String {
    /// Returns nil if empty or just dashes after trimming.
    var trimmedOrNil: String? {
        let t = trimmingCharacters(in: .whitespaces)
        return (t.isEmpty || t == "-") ? nil : t
    }
}
