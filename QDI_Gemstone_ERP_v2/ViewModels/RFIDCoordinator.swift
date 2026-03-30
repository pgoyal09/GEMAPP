import SwiftUI
import SwiftData

/// App-wide RFID state coordinator.
/// Injected via environment so any view can trigger RFID assign sheets.
@MainActor
@Observable
final class RFIDCoordinator {
    let rfidService: RFIDService

    // Assign-sheet state
    var showAssignSheet: Bool = false
    var pendingEpc: String = ""
    var pendingTid: String = ""

    // Connection status
    var isConnected: Bool = false
    var lastError: String?

    init(rfidService: RFIDService) {
        self.rfidService = rfidService
        rfidService.onError = { [weak self] msg in
            Task { @MainActor in self?.lastError = msg }
        }
    }

    func presentAssignSheet(epc: String, tid: String) {
        pendingEpc = epc
        pendingTid = tid
        showAssignSheet = true
    }

    func dismissAssignSheet() {
        showAssignSheet = false
        pendingEpc = ""
        pendingTid = ""
    }

    /// Assign the pending tag to a gemstone, routing through RFIDScanService for uniqueness checks.
    func assignTag(to stone: Gemstone, modelContext: ModelContext) throws {
        let result = RFIDScanService.assignTagToStone(
            epc: pendingEpc,
            tid: pendingTid.isEmpty ? nil : pendingTid,
            stone: stone,
            replaceExisting: true,
            modelContext: modelContext
        )
        switch result {
        case .assigned, .replaced:
            dismissAssignSheet()
        case .conflict(let message):
            lastError = message
        }
    }
}

// Environment key is declared in Services/RFID/RFIDService.swift
