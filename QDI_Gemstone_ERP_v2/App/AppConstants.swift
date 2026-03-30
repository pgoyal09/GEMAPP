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
}

extension Notification.Name {
    static let memoOrInvoiceDidSave = AppConstants.memoOrInvoiceDidSave
}
