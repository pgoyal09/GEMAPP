import Foundation

/// App-wide constants. Centralized here to avoid magic numbers scattered across files.
enum AppConstants {

    // MARK: - Window Sizes

    static let mainWindowWidth: CGFloat = 1200
    static let mainWindowHeight: CGFloat = 780
    static let documentWindowWidth: CGFloat = 1320
    static let documentWindowHeight: CGFloat = 860
    static let documentMinWidth: CGFloat = 1100
    static let documentMinHeight: CGFloat = 760

    // MARK: - Layout

    static let sidebarWidth: CGFloat = 240
    static let inspectorMinWidth: CGFloat = 320
    static let inspectorIdealWidth: CGFloat = 380
    static let inspectorMaxWidth: CGFloat = 480
    static let infoPanelWidth: CGFloat = 296

    // MARK: - Reference Number Defaults

    static let memoStartNumber = 1001
    static let invoiceStartNumber = 2001

    // MARK: - Notifications

    static let memoOrInvoiceDidSave = Notification.Name("com.qdi.gemapp.memoOrInvoiceDidSave")
    /// Posted when a gemstone is created, edited, or deleted so other windows can refresh.
    static let gemstoneDidChange = Notification.Name("com.qdi.gemapp.gemstoneDidChange")
    /// Posted when a customer record is modified.
    static let customerDidChange = Notification.Name("com.qdi.gemapp.customerDidChange")
    /// Generic data-change notification for cross-window refresh when the specific
    /// entity type does not matter (e.g. inventory lists observing any save).
    static let dataStoreDidChange = Notification.Name("com.qdi.gemapp.dataStoreDidChange")
}

extension Notification.Name {
    static let memoOrInvoiceDidSave = AppConstants.memoOrInvoiceDidSave
    static let gemstoneDidChange = AppConstants.gemstoneDidChange
    static let customerDidChange = AppConstants.customerDidChange
    static let dataStoreDidChange = AppConstants.dataStoreDidChange
}
