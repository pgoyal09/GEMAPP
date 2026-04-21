import Foundation
import SwiftData
import os

private let logger = Logger(subsystem: "com.qdi.gemapp", category: "getting-started")

/// Tracks first-run checklist progress using UserDefaults.
/// Displayed on the dashboard after onboarding completes.
enum GettingStartedItem: String, CaseIterable, Identifiable {
    case addFirstStone = "gs_addFirstStone"
    case createMemo = "gs_createMemo"
    case createInvoice = "gs_createInvoice"
    case setupBackup = "gs_setupBackup"
    case explorePrinter = "gs_explorePrinter"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .addFirstStone: return "Add your first stone"
        case .createMemo: return "Create a memo"
        case .createInvoice: return "Create an invoice"
        case .setupBackup: return "Set up backup"
        case .explorePrinter: return "Configure label printer"
        }
    }

    var subtitle: String {
        switch self {
        case .addFirstStone: return "Use Quick Intake (⌘9) or import a CSV"
        case .createMemo: return "Send stones out on consignment"
        case .createInvoice: return "Bill a customer for sold stones"
        case .setupBackup: return "Enable automatic backups in Settings"
        case .explorePrinter: return "Set up your Zebra ZD611R in Settings → Labels"
        }
    }

    var iconName: String {
        switch self {
        case .addFirstStone: return "diamond"
        case .createMemo: return "doc.text"
        case .createInvoice: return "dollarsign.circle"
        case .setupBackup: return "externaldrive.badge.checkmark"
        case .explorePrinter: return "printer"
        }
    }

    var isCompleted: Bool {
        get { UserDefaults.standard.bool(forKey: rawValue) }
        nonmutating set { UserDefaults.standard.set(newValue, forKey: rawValue) }
    }
}

/// Service for managing the getting-started checklist lifecycle.
enum GettingStartedService {

    private static let dismissedKey = "gs_dismissed"

    /// Whether the user has dismissed the checklist entirely.
    static var isDismissed: Bool {
        get { UserDefaults.standard.bool(forKey: dismissedKey) }
        set { UserDefaults.standard.set(newValue, forKey: dismissedKey) }
    }

    /// Whether the checklist should be shown (onboarding complete, not dismissed, not all done).
    static var shouldShow: Bool {
        let onboardingComplete = UserDefaults.standard.bool(forKey: "onboardingComplete")
        return onboardingComplete && !isDismissed && !allCompleted
    }

    /// Number of completed items.
    static var completedCount: Int {
        GettingStartedItem.allCases.filter(\.isCompleted).count
    }

    /// Total number of items.
    static var totalCount: Int {
        GettingStartedItem.allCases.count
    }

    /// Whether all items are completed.
    static var allCompleted: Bool {
        completedCount == totalCount
    }

    /// Mark an item as completed.
    static func markCompleted(_ item: GettingStartedItem) {
        guard !item.isCompleted else { return }
        item.isCompleted = true
        logger.info("Getting started: completed '\(item.title, privacy: .public)'")
    }

    /// Dismiss the checklist permanently.
    static func dismiss() {
        isDismissed = true
        logger.info("Getting started checklist dismissed")
    }

    /// Automatically detect completed items by checking current data state.
    @MainActor
    static func autoDetectProgress(modelContext: ModelContext) {
        // Check if stones exist
        var stoneDesc = FetchDescriptor<Gemstone>()
        stoneDesc.fetchLimit = 1
        if let count = try? modelContext.fetchCount(stoneDesc), count > 0 {
            markCompleted(.addFirstStone)
        }

        // Check if memos exist
        var memoDesc = FetchDescriptor<Memo>()
        memoDesc.fetchLimit = 1
        if let count = try? modelContext.fetchCount(memoDesc), count > 0 {
            markCompleted(.createMemo)
        }

        // Check if invoices exist
        var invoiceDesc = FetchDescriptor<Invoice>()
        invoiceDesc.fetchLimit = 1
        if let count = try? modelContext.fetchCount(invoiceDesc), count > 0 {
            markCompleted(.createInvoice)
        }

        // Check if backup is configured
        if UserDefaults.standard.bool(forKey: "autoBackupEnabled") {
            markCompleted(.setupBackup)
        }
    }

    /// Reset all checklist progress (for testing/demo reset).
    static func reset() {
        for item in GettingStartedItem.allCases {
            item.isCompleted = false
        }
        isDismissed = false
    }
}
