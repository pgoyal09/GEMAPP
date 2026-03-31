import Foundation
import SwiftData

/// Batch reconciliation: compare scanned tags against expected inventory.
enum RFIDReconciliationService {

    struct ReconciliationResult {
        let matched: [Gemstone]
        let missing: [Gemstone]
        let unknown: [String]
        let timestamp: Date
    }

    /// Reconcile scanned RFID tags against all stones that have an assigned RFID.
    @MainActor
    static func reconcile(scannedTags: [String], modelContext: ModelContext) -> ReconciliationResult {
        // Normalize scanned tags
        let normalizedScans = Set(scannedTags.compactMap { EPCanonical.canonicalHex(fromRawHex: $0) ?? $0.uppercased() })

        // Fetch all stones with RFID tags assigned
        let descriptor = FetchDescriptor<Gemstone>()
        let allStones = (try? modelContext.fetch(descriptor)) ?? []
        let stonesWithRFID = allStones.filter { $0.rfidEpc != nil }

        var matched: [Gemstone] = []
        var missing: [Gemstone] = []
        var matchedEPCs: Set<String> = []

        for stone in stonesWithRFID {
            guard let epc = stone.rfidEpc else { continue }
            if normalizedScans.contains(epc.uppercased()) {
                matched.append(stone)
                matchedEPCs.insert(epc.uppercased())
            } else {
                missing.append(stone)
            }
        }

        // Unknown tags: scanned but not in DB
        let unknown = normalizedScans.filter { !matchedEPCs.contains($0) }.sorted()

        return ReconciliationResult(
            matched: matched,
            missing: missing.sorted { $0.sku < $1.sku },
            unknown: unknown,
            timestamp: Date()
        )
    }

    /// Generate discrepancy CSV report.
    static func generateDiscrepancyReport(_ result: ReconciliationResult) -> String {
        var lines = [
            "RFID Reconciliation Report",
            "Date: \(result.timestamp.formatted(.dateTime.year().month().day().hour().minute()))",
            "Matched: \(result.matched.count)",
            "Missing: \(result.missing.count)",
            "Unknown: \(result.unknown.count)",
            "",
            "Status,SKU,Type,Carats,EPC,Location"
        ]

        for stone in result.matched {
            lines.append("Matched,\(stone.sku),\(stone.stoneType.rawValue),\(String(format: "%.2f", stone.caratWeight)),\(stone.rfidEpc ?? ""),\(stone.currentLocation)")
        }
        for stone in result.missing {
            lines.append("Missing,\(stone.sku),\(stone.stoneType.rawValue),\(String(format: "%.2f", stone.caratWeight)),\(stone.rfidEpc ?? ""),\(stone.currentLocation)")
        }
        for epc in result.unknown {
            lines.append("Unknown,,,,\(epc),")
        }

        return lines.joined(separator: "\n")
    }
}
