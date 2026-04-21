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
