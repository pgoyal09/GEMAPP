import SwiftUI
import SwiftData

/// Tracks which memo/invoice documents have open windows.
/// All access occurs through SwiftUI views (main actor).
@Observable
final class OpenDocumentTracker: @unchecked Sendable {
    private var openMemoIDs: Set<PersistentIdentifier> = []
    private var openInvoiceIDs: Set<PersistentIdentifier> = []

    func isOpen(memoID: PersistentIdentifier) -> Bool { openMemoIDs.contains(memoID) }
    func isOpen(invoiceID: PersistentIdentifier) -> Bool { openInvoiceIDs.contains(invoiceID) }

    func trackOpen(memoID: PersistentIdentifier) { openMemoIDs.insert(memoID) }
    func trackClose(memoID: PersistentIdentifier) { openMemoIDs.remove(memoID) }
    func trackOpen(invoiceID: PersistentIdentifier) { openInvoiceIDs.insert(invoiceID) }
    func trackClose(invoiceID: PersistentIdentifier) { openInvoiceIDs.remove(invoiceID) }

    // MARK: - Stone Locking

    /// Maps stone ID → document description (e.g. "Memo #M-0012") for conflict messages.
    private var lockedStones: [PersistentIdentifier: String] = [:]

    /// Lock stones when they're added to an open document.
    func lockStone(_ stoneID: PersistentIdentifier, by documentRef: String) {
        lockedStones[stoneID] = documentRef
    }

    /// Unlock a stone when removed from a document or document closes.
    func unlockStone(_ stoneID: PersistentIdentifier) {
        lockedStones.removeValue(forKey: stoneID)
    }

    /// Unlock all stones associated with a set of stone IDs (used on document close).
    func unlockStones(_ stoneIDs: Set<PersistentIdentifier>) {
        for id in stoneIDs { lockedStones.removeValue(forKey: id) }
    }

    /// Check if a stone is locked by another document. Returns the locking doc ref if locked, nil if free.
    func lockingDocument(for stoneID: PersistentIdentifier) -> String? {
        lockedStones[stoneID]
    }
}

// MARK: - Environment Key

private struct OpenDocumentTrackerKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue = OpenDocumentTracker()
}

extension EnvironmentValues {
    var openDocumentTracker: OpenDocumentTracker {
        get { self[OpenDocumentTrackerKey.self] }
        set { self[OpenDocumentTrackerKey.self] = newValue }
    }
}
