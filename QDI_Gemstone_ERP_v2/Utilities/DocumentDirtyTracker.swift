import SwiftUI

/// Tracks unsaved changes across memo and invoice document windows.
@Observable
final class DocumentDirtyTracker {
    var hasUnsavedMemo = false
    var hasUnsavedInvoice = false
    var showUnsavedAlert = false
    var onSaveAndClose: (() -> Void)?

    var hasAnyDirty: Bool { hasUnsavedMemo || hasUnsavedInvoice }
    var isDirty: Bool { hasAnyDirty }

    func markDirty() { hasUnsavedMemo = true }
    func clearDirty() { hasUnsavedMemo = false; hasUnsavedInvoice = false }
    func clearMemoDirty() { hasUnsavedMemo = false }
    func clearInvoiceDirty() { hasUnsavedInvoice = false }
}

// MARK: - Environment Key

private struct DocumentDirtyTrackerKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue = DocumentDirtyTracker()
}

extension EnvironmentValues {
    var documentDirtyTracker: DocumentDirtyTracker {
        get { self[DocumentDirtyTrackerKey.self] }
        set { self[DocumentDirtyTrackerKey.self] = newValue }
    }
}
