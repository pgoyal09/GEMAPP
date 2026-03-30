import Foundation
import SwiftData
import os

private let scannerLog = Logger(subsystem: "com.qdi.gemapp", category: "rfid.scanner")

@MainActor
@Observable
final class ScannerViewModel {
    private let rfidService: RFIDService
    private weak var rfidCoordinator: RFIDCoordinator?

    var isScanning: Bool = false
    var lastDiscoveredTagID: String?
    var discoveredTagIDs: [String] = []
    var lastProcessResult: String?
    var modelContext: ModelContext?

    /// Tracks the last time each tag was processed; prevents re-processing within 15 seconds.
    private var lastProcessedTimes: [String: Date] = [:]
    private static let rescanCooldown: TimeInterval = 15

    /// Batch processing: collect tags within a 200ms window before processing.
    private var pendingTags: [String] = []
    private var batchWorkItem: DispatchWorkItem?
    private static let batchWindow: TimeInterval = 0.2

    init(rfidService: RFIDService, rfidCoordinator: RFIDCoordinator? = nil) {
        self.rfidService = rfidService
        self.rfidCoordinator = rfidCoordinator
    }

    func attachScanHandler() {
        rfidService.onTagDiscovered = { [weak self] tagID in
            Task { @MainActor in
                self?.didDiscoverTag(tagID)
            }
        }
    }

    func detachScanHandler() {
        rfidService.onTagDiscovered = nil
    }

    func startScanning() {
        rfidService.startScanning()
        isScanning = true
    }

    func stopScanning() {
        rfidService.stopScanning()
        isScanning = false
    }

    func clearDiscoveredTags() {
        discoveredTagIDs.removeAll()
        lastDiscoveredTagID = nil
        lastProcessResult = nil
        lastProcessedTimes.removeAll()
    }

    private func didDiscoverTag(_ tagID: String) {
        let now = Date()
        if let lastSeen = lastProcessedTimes[tagID],
           now.timeIntervalSince(lastSeen) < Self.rescanCooldown {
            return
        }

        // Batch incoming tags within a 200ms window
        pendingTags.append(tagID)
        batchWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.processPendingBatch()
            }
        }
        batchWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.batchWindow, execute: workItem)
    }

    private func processPendingBatch() {
        let tags = pendingTags
        pendingTags.removeAll()
        let now = Date()
        for tagID in tags {
            // Re-check cooldown (tag may have been queued multiple times)
            if let lastSeen = lastProcessedTimes[tagID],
               now.timeIntervalSince(lastSeen) < Self.rescanCooldown {
                continue
            }
            lastProcessedTimes[tagID] = now
            lastDiscoveredTagID = tagID
            discoveredTagIDs.append(tagID)
            if let ctx = modelContext {
                processScannedTag(tagID: tagID, modelContext: ctx)
            }
        }
    }

    func processScannedTag(tagID: String, modelContext: ModelContext) {
        lastProcessResult = nil
        let rawHex = tagID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawHex.isEmpty else {
            lastProcessResult = "Empty tag ID"
            return
        }

        let result = RFIDScanService.processScannedTag(rawHex: rawHex, modelContext: modelContext)
        switch result {
        case .matched(let stone):
            switch stone.status {
            case .available:
                addStoneToNewMemo(stone: stone, modelContext: modelContext)
            case .onMemo:
                returnStoneFromMemo(stone: stone, modelContext: modelContext)
            case .sold:
                lastProcessResult = "Stone already sold"
            }
        case .unknownTag(let epc, let tid):
            lastProcessResult = "Unknown tag"
            rfidCoordinator?.presentAssignSheet(epc: epc, tid: tid ?? "")
        }
    }

    private func addStoneToNewMemo(stone: Gemstone, modelContext: ModelContext) {
        do {
            let memo = try TransactionService.createMemo(modelContext: modelContext)
            try TransactionService.addStone(stone, to: memo, modelContext: modelContext)
            lastProcessResult = "Added to Memo #\(memo.referenceNumber)"
        } catch {
            scannerLog.error("Scanner memo creation failed: \(error.localizedDescription, privacy: .public)")
            lastProcessResult = "Failed to save: \(error.localizedDescription)"
        }
    }

    private func returnStoneFromMemo(stone: Gemstone, modelContext: ModelContext) {
        guard let memo = stone.memo,
              let item = memo.openLineItems.first(where: { $0.gemstone?.sku == stone.sku }) else {
            stone.status = .available
            stone.memo = nil
            do { try modelContext.save() } catch {
                scannerLog.error("Orphan return failed: \(error.localizedDescription, privacy: .public)")
            }
            lastProcessResult = "Returned to stock (no memo link)"
            return
        }

        do {
            try MemoService.returnItems([item], modelContext: modelContext)
            lastProcessResult = "Returned from Memo #\(memo.referenceNumber)"
        } catch {
            scannerLog.error("Return failed: \(error.localizedDescription, privacy: .public)")
            lastProcessResult = "Failed to return"
        }
    }
}
