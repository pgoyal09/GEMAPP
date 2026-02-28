import Foundation
import SwiftData

// MARK: - Reconcile ViewModel (Section 10: all comparison logic here; view only displays)

@MainActor
@Observable
final class ReconcileViewModel {
    private let rfidService: RFIDService
    private weak var rfidCoordinator: RFIDCoordinator?

    /// All gemstones in DB where status == .available.
    private(set) var availableStones: [Gemstone] = []

    /// Tag IDs (EPC) scanned during this session (order preserved).
    private(set) var scannedTagIDs: [String] = []

    /// Tag IDs that matched an available stone (marked as Found).
    private(set) var foundTagIDs: Set<String> = []

    /// Reason for extra scans: "Not in database", "Sold", "On memo", etc.
    private(set) var extraScanReasons: [String: String] = [:]

    var isScanning: Bool = false

    /// ModelContext set by the view so we can fetch/lookup when tags arrive.
    var modelContext: ModelContext?

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
        availableStones = all.filter { $0.effectiveStatus == .available }
    }
    
    func startScanning() {
        rfidService.startScanning()
        isScanning = true
    }
    
    func stopScanning() {
        rfidService.stopScanning()
        isScanning = false
    }
    
    /// Reset scanned/found state for a new reconciliation run.
    func resetScan() {
        scannedTagIDs.removeAll()
        foundTagIDs.removeAll()
        extraScanReasons.removeAll()
    }
    
    /// Called when RFID sends a tag. Uses RFIDScanService; marks available stones as Found; unknown tags open assign sheet.
    private func registerScannedTag(_ tagID: String) {
        let rawHex = tagID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawHex.isEmpty else { return }

        guard let modelContext = modelContext else {
            scannedTagIDs.append(rawHex)
            extraScanReasons[rawHex] = "Not in database"
            return
        }

        let result = RFIDScanService.processScannedTag(rawHex: rawHex, modelContext: modelContext)
        switch result {
        case .matched(let stone):
            let epc = stone.effectiveRfidEpc ?? rawHex
            scannedTagIDs.append(epc)
            switch stone.effectiveStatus {
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
            rfidCoordinator?.presentAssignSheet(epc: epc, tid: tid)
        }
    }
    
    // MARK: - Comparison (View only reads these)
    
    /// Stones in DB as .available but NOT scanned (Missing).
    var missingStones: [Gemstone] {
        availableStones.filter { stone in
            guard let tag = stone.effectiveRfidEpc else { return true }
            return !foundTagIDs.contains(tag)
        }
    }

    /// Stones in DB as .available that were scanned (Found). Pastel Blue.
    var foundStones: [Gemstone] {
        availableStones.filter { stone in
            guard let tag = stone.effectiveRfidEpc else { return false }
            return foundTagIDs.contains(tag)
        }
    }
    
    /// Scanned tag IDs that are NOT in DB or stone is sold/on memo (Extra). Pastel Red.
    var extraScans: [(tagID: String, reason: String)] {
        scannedTagIDs.filter { !foundTagIDs.contains($0) }.map { tagID in
            (tagID, extraScanReasons[tagID] ?? "Unknown")
        }
    }
}
