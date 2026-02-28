import Foundation
import SwiftData

// MARK: - Scanner ViewModel (MVVM: all scanning logic here; view only binds)

@MainActor
@Observable
final class ScannerViewModel {
    private let rfidService: RFIDService
    private weak var rfidCoordinator: RFIDCoordinator?

    var isScanning: Bool = false
    var lastDiscoveredTagID: String?
    var discoveredTagIDs: [String] = []

    /// Result of last processScannedTag for UI (e.g. "Added to memo", "Returned to stock", "Unknown tag").
    var lastProcessResult: String?

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
    }
    
    private func didDiscoverTag(_ tagID: String) {
        lastDiscoveredTagID = tagID
        discoveredTagIDs.append(tagID)
    }
    
    /// Process a scanned tag: lookup via RFIDScanService; if matched add/return; if unknown show assign sheet.
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
            switch stone.effectiveStatus {
            case .available:
                addStoneToNewMemo(stone: stone, modelContext: modelContext)
            case .onMemo:
                returnStoneFromMemo(stone: stone, modelContext: modelContext)
            case .sold:
                lastProcessResult = "Stone already sold"
            }
        case .unknownTag(let epc, let tid):
            lastProcessResult = "Unknown tag"
            rfidCoordinator?.presentAssignSheet(epc: epc, tid: tid)
        }
    }
    
    /// Add gemstone to a new Memo as an Inventory line item. No force-unwrapping.
    private func addStoneToNewMemo(stone: Gemstone, modelContext: ModelContext) {
        let refNumber = TransactionViewModel.generateNextMemoNumber(modelContext: modelContext)
        let memo = Memo(
            status: .onMemo,
            dateAssigned: Date(),
            referenceNumber: refNumber,
            customer: nil
        )
        modelContext.insert(memo)
        
        let amount = stone.sellPrice * Decimal(stone.caratWeight)
        let lineItem = LineItem(
            sku: stone.sku,
            itemDescription: "\(stone.stoneType.rawValue) \(stone.color) \(stone.clarity) \(stone.cut)",
            carats: stone.caratWeight,
            rate: stone.sellPrice,
            amount: amount,
            gemstone: stone,
            isService: false,
            status: .open
        )
        lineItem.memo = memo
        modelContext.insert(lineItem)
        
        stone.status = .onMemo
        stone.memo = memo
        
        logEvent(
            stone: stone,
            type: .sentToCustomer,
            message: "Added to Memo #\(refNumber) via scanner",
            modelContext: modelContext
        )
        
        do {
            try modelContext.save()
            lastProcessResult = "Added to Memo #\(refNumber)"
        } catch {
            lastProcessResult = "Failed to save: \(error.localizedDescription)"
        }
    }
    
    /// Return stone from its current memo: set .available, log history, remove from memo. No force-unwrapping.
    private func returnStoneFromMemo(stone: Gemstone, modelContext: ModelContext) {
        guard let memo = stone.memo else {
            stone.status = .available
            stone.memo = nil
            try? modelContext.save()
            lastProcessResult = "Returned to stock (no memo link)"
            return
        }
        
        guard let lineItem = memo.lineItems.first(where: { $0.gemstone?.id == stone.id }) else {
            stone.status = .available
            stone.memo = nil
            try? modelContext.save()
            lastProcessResult = "Returned to stock"
            return
        }
        
        TransactionViewModel.returnItemsFromMemo(items: [lineItem], modelContext: modelContext)
        lastProcessResult = "Returned to stock from Memo #\(memo.referenceNumber ?? "?")"
    }
}
