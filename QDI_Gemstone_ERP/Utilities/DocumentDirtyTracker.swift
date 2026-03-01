import SwiftUI

/// Tracks unsaved changes in memo/invoice document windows. Used by MemosView/InvoiceListView
/// to report to NavigationGuard when sidebar nav should prompt.
@Observable
final class DocumentDirtyTracker {
    var hasUnsavedMemo: Bool = false
    var hasUnsavedInvoice: Bool = false

    var hasAnyDirty: Bool { hasUnsavedMemo || hasUnsavedInvoice }
}

private struct DocumentDirtyTrackerKey: EnvironmentKey {
    static let defaultValue: DocumentDirtyTracker? = nil
}

extension EnvironmentValues {
    var documentDirtyTracker: DocumentDirtyTracker? {
        get { self[DocumentDirtyTrackerKey.self] }
        set { self[DocumentDirtyTrackerKey.self] = newValue }
    }
}
