import Foundation
import SwiftData

@MainActor
@Observable
final class ReconcileViewModel {
    private let rfidService: RFIDService
    private weak var rfidCoordinator: RFIDCoordinator?

    private(set) var availableStones: [Gemstone] = []
    private(set) var scannedTagIDs: [String] = []
    private(set) var foundTagIDs: Set<String> = []
    private(set) var extraScanReasons: [String: String] = [:]

    var isScanning: Bool = false
    var modelContext: ModelContext?
    var lastReconciliationDate: Date?

    /// Manual reconciliation: set of stone IDs physically verified without RFID.
    var manuallyVerifiedIDs: Set<PersistentIdentifier> = []
    var isManualMode: Bool = false

    init(rfidService: RFIDService, rfidCoordinator: RFIDCoordinator? = nil) {
        self.rfidService = rfidService
        self.rfidCoordinator = rfidCoordinator
    }

    func attachScanHandler() {
        rfidService.onTagDiscovered = { [weak self] tagID in
            Task { @MainActor in
                self?.registerScannedTag(tagID)
            }
        }
    }

    func detachScanHandler() {
        rfidService.onTagDiscovered = nil
    }

    func load(modelContext: ModelContext) {
        self.modelContext = modelContext
        let descriptor = FetchDescriptor<Gemstone>(sortBy: [SortDescriptor(\.sku)])
        let all = (try? modelContext.fetch(descriptor)) ?? []
        availableStones = all.filter { $0.status == .available }
    }

    func startScanning() {
        rfidService.startScanning()
        isScanning = true
    }

    func stopScanning() {
        rfidService.stopScanning()
        isScanning = false
        lastReconciliationDate = Date()
    }

    func resetScan() {
        scannedTagIDs.removeAll()
        foundTagIDs.removeAll()
        extraScanReasons.removeAll()
        manuallyVerifiedIDs.removeAll()
    }

    func toggleManualVerification(for stone: Gemstone) {
        if manuallyVerifiedIDs.contains(stone.persistentModelID) {
            manuallyVerifiedIDs.remove(stone.persistentModelID)
        } else {
            manuallyVerifiedIDs.insert(stone.persistentModelID)
        }
    }

    // MARK: - Comparison Results

    var missingStones: [Gemstone] {
        availableStones.filter { stone in
            // Manual mode: checked off stones are "found"
            if manuallyVerifiedIDs.contains(stone.persistentModelID) { return false }
            guard let tag = stone.rfidEpc else { return true }
            return !foundTagIDs.contains(tag)
        }
    }

    var foundStones: [Gemstone] {
        availableStones.filter { stone in
            if manuallyVerifiedIDs.contains(stone.persistentModelID) { return true }
            guard let tag = stone.rfidEpc else { return false }
            return foundTagIDs.contains(tag)
        }
    }

    var extraScans: [(tagID: String, reason: String)] {
        scannedTagIDs
            .filter { !foundTagIDs.contains($0) }
            .map { ($0, extraScanReasons[$0] ?? "Unknown") }
    }

    // MARK: - Export

    func exportReconciliationReport() -> String {
        var lines: [String] = []
        let dateStr = lastReconciliationDate?.formatted(.dateTime.year().month().day().hour().minute()) ?? "N/A"
        lines.append("Reconciliation Report")
        lines.append("Date: \(dateStr)")
        lines.append("Total Expected: \(availableStones.count)")
        lines.append("Found: \(foundStones.count)")
        lines.append("Missing: \(missingStones.count)")
        lines.append("Extra Scans: \(extraScans.count)")
        lines.append("")

        lines.append("Status,SKU,Stone Type,Carats,RFID EPC,Reason")

        for stone in foundStones {
            lines.append("Found,\(stone.sku.csvEscaped),\(stone.stoneType.rawValue.csvEscaped),\(String(format: "%.2f", stone.caratWeight)),\(stone.rfidEpc?.csvEscaped ?? "N/A"),Matched")
        }

        for stone in missingStones {
            lines.append("Missing,\(stone.sku.csvEscaped),\(stone.stoneType.rawValue.csvEscaped),\(String(format: "%.2f", stone.caratWeight)),\(stone.rfidEpc?.csvEscaped ?? "No tag"),Not scanned")
        }

        for scan in extraScans {
            lines.append("Extra,\(scan.tagID.csvEscaped),,,\(scan.reason.csvEscaped)")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Private

    private func registerScannedTag(_ tagID: String) {
        let rawHex = tagID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawHex.isEmpty else { return }

        guard let modelContext else {
            scannedTagIDs.append(rawHex)
            extraScanReasons[rawHex] = "Not in database"
            return
        }

        let result = RFIDScanService.processScannedTag(rawHex: rawHex, modelContext: modelContext)
        switch result {
        case .matched(let stone):
            let epc = stone.rfidEpc ?? rawHex
            scannedTagIDs.append(epc)
            switch stone.status {
            case .available:
                foundTagIDs.insert(epc)
                extraScanReasons.removeValue(forKey: epc)
            case .sold:
                extraScanReasons[epc] = "Sold"
            case .onMemo:
                extraScanReasons[epc] = "On memo"
            }
        case .unknownTag(let epc, let tid):
            scannedTagIDs.append(epc)
            extraScanReasons[epc] = "Not in database"
            rfidCoordinator?.presentAssignSheet(epc: epc, tid: tid ?? "")
        }
    }
}
