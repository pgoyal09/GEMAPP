import Foundation
import SwiftData

/// Generates SKUs in format TYPE-SHAPE-GROUP-NNN.
enum SKUGenerator {

    /// Generate a new unique SKU for the given parameters.
    @MainActor
    static func generate(
        type: StoneType,
        shape: String,
        grouping: StoneGrouping,
        modelContext: ModelContext
    ) -> String {
        let prefix = buildPrefix(type: type, shape: shape, grouping: grouping)
        let seq = nextSequence(prefix: prefix, modelContext: modelContext)
        return "\(prefix)\(String(format: "%03d", seq))"
    }

    /// Resolve SKU for save: use candidate if non-empty, else generate. Always unique.
    @MainActor
    static func resolveForSave(
        candidate: String?,
        type: StoneType,
        shape: String,
        grouping: StoneGrouping,
        modelContext: ModelContext
    ) -> String {
        let trimmed = (candidate ?? "").trimmingCharacters(in: .whitespaces)
        let sku = trimmed.isEmpty
            ? generate(type: type, shape: shape, grouping: grouping, modelContext: modelContext)
            : trimmed
        return ensureUnique(sku, modelContext: modelContext)
    }

    /// Resolve SKU for edit: keep existing if prefix matches, else regenerate.
    @MainActor
    static func resolveForEdit(
        candidate: String?,
        existingSKU: String,
        type: StoneType,
        shape: String,
        grouping: StoneGrouping,
        modelContext: ModelContext,
        excludingID: PersistentIdentifier? = nil
    ) -> String {
        let trimmed = (candidate ?? "").trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            return ensureUnique(trimmed, excludingID: excludingID, modelContext: modelContext)
        }
        let prefix = buildPrefix(type: type, shape: shape, grouping: grouping)
        if existingSKU.hasPrefix(prefix) {
            return existingSKU
        }
        return ensureUnique(
            generate(type: type, shape: shape, grouping: grouping, modelContext: modelContext),
            excludingID: excludingID,
            modelContext: modelContext
        )
    }

    /// Check if a SKU already exists.
    @MainActor
    static func exists(
        sku: String,
        excludingID: PersistentIdentifier? = nil,
        modelContext: ModelContext
    ) -> Bool {
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

    /// Expected prefix for given parameters (without sequence number).
    static func expectedPrefix(type: StoneType, shape: String, grouping: StoneGrouping) -> String {
        buildPrefix(type: type, shape: shape, grouping: grouping)
    }

    /// Returns true if SKU prefix matches the given type/shape/grouping.
    static func prefixMatches(sku: String, type: StoneType, shape: String, grouping: StoneGrouping) -> Bool {
        sku.hasPrefix(buildPrefix(type: type, shape: shape, grouping: grouping))
    }

    // MARK: - Private

    private static func buildPrefix(type: StoneType, shape: String, grouping: StoneGrouping) -> String {
        "\(type.skuCode)-\(StoneShape.skuCode(from: shape))-\(grouping.skuCode)-"
    }

    @MainActor
    private static func nextSequence(prefix: String, modelContext: ModelContext) -> Int {
        // Optimized: fetch only the latest SKU for this prefix instead of full table scan.
        // Use a predicate that checks hasPrefix, sort descending, fetchLimit 1.
        let prefixStr = prefix
        var descriptor = FetchDescriptor<Gemstone>(
            predicate: #Predicate<Gemstone> { $0.sku.starts(with: prefixStr) },
            sortBy: [SortDescriptor(\.sku, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        guard let results = try? modelContext.fetch(descriptor),
              let latest = results.first else {
            return 1
        }
        let seqString = String(latest.sku.dropFirst(prefix.count))
        return (Int(seqString) ?? 0) + 1
    }

    @MainActor
    private static func ensureUnique(
        _ sku: String,
        excludingID: PersistentIdentifier? = nil,
        modelContext: ModelContext
    ) -> String {
        var candidate = sku.trimmingCharacters(in: .whitespaces)
        if candidate.isEmpty { candidate = "TMP-OT-S-001" }

        // Optimized: check one SKU at a time with a targeted predicate + fetchLimit: 1
        // instead of fetching ALL gemstones.
        func skuExists(_ skuToCheck: String) -> Bool {
            let check = skuToCheck
            var desc = FetchDescriptor<Gemstone>(
                predicate: #Predicate<Gemstone> { $0.sku == check }
            )
            desc.fetchLimit = 1
            guard let matches = try? modelContext.fetch(desc) else { return false }
            if let id = excludingID {
                return matches.contains { $0.id != id }
            }
            return !matches.isEmpty
        }

        if !skuExists(candidate) { return candidate }

        let parts = candidate.split(separator: "-")
        let base = parts.count >= 4 ? parts.prefix(3).joined(separator: "-") + "-" : candidate + "-"
        var seq = (parts.count >= 4 ? Int(parts[3]) : nil) ?? 1

        for _ in 0..<10_000 {
            seq += 1
            let attempt = base + String(format: "%03d", seq)
            if !skuExists(attempt) { return attempt }
        }
        return candidate
    }
}
