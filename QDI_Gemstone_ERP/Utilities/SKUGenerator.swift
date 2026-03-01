import Foundation
import SwiftData

/// Generates SKUs in format TYPE-SHAPE-GROUP-NNN
/// Use generateSKU() as the single entry point for all intake/review/edit flows.
enum SKUGenerator {

    static func stoneTypeCode(_ type: StoneType) -> String {
        switch type {
        case .diamond: return "DI"
        case .emerald: return "EM"
        case .ruby: return "RU"
        case .tanzanite: return "TZ"
        case .sapphire: return "SA"
        }
    }

    static func shapeCode(_ shape: IntakeShape) -> String {
        switch shape {
        case .round: return "RD"
        case .oval: return "OV"
        case .cushion: return "CU"
        case .pear: return "PR"
        case .emerald: return "EM"
        case .princess: return "PS"
        case .radiant: return "RA"
        case .marquise: return "MQ"
        case .heart: return "HT"
        case .asscher: return "AS"
        case .cabochon: return "CB"
        case .other: return "OT"
        }
    }

    static func groupingCode(_ g: IntakeGrouping) -> String {
        switch g {
        case .single: return "S"
        case .pair: return "P"
        case .lot: return "L"
        }
    }

    /// Expected prefix for given type/shape/group (without sequence number)
    static func expectedPrefix(type: StoneType, shapeString: String, grouping: IntakeGrouping) -> String {
        let shape = IntakeShape(rawValue: shapeString) ?? .other
        return "\(stoneTypeCode(type))-\(shapeCode(shape))-\(groupingCode(grouping))-"
    }

    /// Returns true if the SKU prefix matches the given type/shape/group
    static func prefixMatches(sku: String, type: StoneType, shapeString: String, grouping: IntakeGrouping) -> Bool {
        sku.hasPrefix(expectedPrefix(type: type, shapeString: shapeString, grouping: grouping))
    }

    /// Single canonical SKU generator - use this everywhere for intake/review/edit.
    /// Generates from current type, shape string, and grouping only.
    static func generateSKU(
        type: StoneType,
        shape: String,
        grouping: IntakeGrouping,
        modelContext: ModelContext
    ) -> String {
        generate(type: type, shapeString: shape, grouping: grouping, modelContext: modelContext)
    }

    /// Resolves final SKU for save: prefers candidate (user-edited) when non-empty; else generates.
    /// Always returns unique SKU. Manual SKUs are allowed regardless of prefix.
    static func resolveSKUForSave(
        candidateSKU: String?,
        type: StoneType,
        shape: String,
        grouping: IntakeGrouping,
        modelContext: ModelContext
    ) -> String {
        let candidate = (candidateSKU ?? "").trimmingCharacters(in: .whitespaces)
        let generated = generateSKU(type: type, shape: shape, grouping: grouping, modelContext: modelContext)
        if !candidate.isEmpty {
            return ensureUnique(candidate, modelContext: modelContext)
        }
        return ensureUnique(generated, modelContext: modelContext)
    }

    /// Preserves existing SKU if prefix matches; otherwise regenerates. Use when editing existing stone.
    /// Prefers candidateSKU when provided and non-empty (manual override).
    static func resolveSKUForEdit(
        candidateSKU: String?,
        existingSKU: String,
        type: StoneType,
        shape: String,
        grouping: IntakeGrouping,
        modelContext: ModelContext,
        excludingID: PersistentIdentifier? = nil
    ) -> String {
        let candidate = (candidateSKU ?? "").trimmingCharacters(in: .whitespaces)
        if !candidate.isEmpty {
            return ensureUnique(candidate, excludingID: excludingID, modelContext: modelContext)
        }
        if prefixMatches(sku: existingSKU, type: type, shapeString: shape, grouping: grouping) {
            return existingSKU
        }
        #if DEBUG
        print("[SKUGenerator] Edit mismatch: existing SKU '\(existingSKU)' does not match type=\(type.rawValue). Regenerating.")
        #endif
        return ensureUnique(generateSKU(type: type, shape: shape, grouping: grouping, modelContext: modelContext), modelContext: modelContext)
    }

    /// Generate next sequence for TYPE-SHAPE-GROUP prefix. Fetches existing SKUs and increments.
    static func nextSequence(
        type: StoneType,
        shape: IntakeShape,
        grouping: IntakeGrouping,
        modelContext: ModelContext
    ) -> Int {
        let prefix = "\(stoneTypeCode(type))-\(shapeCode(shape))-\(groupingCode(grouping))-"
        let descriptor = FetchDescriptor<Gemstone>()
        let all = (try? modelContext.fetch(descriptor)) ?? []
        let matching = all.filter { $0.sku.starts(with: prefix) }
        let nums = matching.compactMap { s -> Int? in
            let suffix = String(s.sku.dropFirst(prefix.count))
            return Int(suffix)
        }
        return (nums.max() ?? 0) + 1
    }

    static func generate(
        type: StoneType,
        shape: IntakeShape,
        grouping: IntakeGrouping,
        modelContext: ModelContext
    ) -> String {
        let seq = nextSequence(type: type, shape: shape, grouping: grouping, modelContext: modelContext)
        return "\(stoneTypeCode(type))-\(shapeCode(shape))-\(groupingCode(grouping))-\(String(format: "%03d", seq))"
    }

    /// Generate SKU using shape string (e.g. "Round"); uses .other if not in IntakeShape.
    static func generate(
        type: StoneType,
        shapeString: String,
        grouping: IntakeGrouping,
        modelContext: ModelContext
    ) -> String {
        let shape = IntakeShape(rawValue: shapeString) ?? .other
        return generate(type: type, shape: shape, grouping: grouping, modelContext: modelContext)
    }

    static func shapeCode(from shapeString: String) -> String {
        shapeCode(IntakeShape(rawValue: shapeString) ?? .other)
    }

    /// Ensure SKU is unique; if not, increment sequence until unique.
    /// Pass excludingID to ignore a stone (e.g. current stone when editing).
    static func ensureUnique(_ sku: String, excludingID: PersistentIdentifier? = nil, modelContext: ModelContext) -> String {
        let descriptor = FetchDescriptor<Gemstone>()
        var all = (try? modelContext.fetch(descriptor)) ?? []
        if let id = excludingID {
            all = all.filter { $0.id != id }
        }
        let existingSKUs = Set(all.map(\.sku))
        var candidate = sku.trimmingCharacters(in: .whitespaces)
        if candidate.isEmpty { candidate = "TMP-OT-S-001" }
        let parts = candidate.split(separator: "-")
        let base = parts.count >= 4 ? parts.prefix(3).joined(separator: "-") + "-" : candidate + "-"
        var seq = (parts.count >= 4 ? Int(parts[3]) : nil) ?? 1
        for _ in 0..<10_000 {
            candidate = base + String(format: "%03d", seq)
            if !existingSKUs.contains(candidate) { return candidate }
            seq += 1
        }
        return candidate
    }

    /// Returns true if a gemstone with this SKU exists. Pass excludingID to ignore the current stone when editing.
    static func skuExists(sku: String, excludingID: PersistentIdentifier?, modelContext: ModelContext) -> Bool {
        let trimmed = sku.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        let descriptor = FetchDescriptor<Gemstone>(
            predicate: #Predicate<Gemstone> { $0.sku == trimmed }
        )
        guard let matches = try? modelContext.fetch(descriptor) else { return false }
        if let id = excludingID {
            return matches.contains { $0.id != id }
        }
        return !matches.isEmpty
    }

    /// Debug: scan gemstones for SKU/type mismatches. Returns stones whose SKU prefix doesn't match their stoneType.
    static func findSKUTypeMismatches(modelContext: ModelContext) -> [Gemstone] {
        let descriptor = FetchDescriptor<Gemstone>()
        let all = (try? modelContext.fetch(descriptor)) ?? []
        return all.filter { stone in
            let g: IntakeGrouping = stone.grouping == "P" ? .pair : (stone.grouping == "L" ? .lot : .single)
            let expected = "\(stoneTypeCode(stone.stoneType))-\(shapeCode(from: stone.shape ?? "Other"))-\(groupingCode(g))-"
            return !stone.sku.hasPrefix(expected)
        }
    }
}
