import Foundation
import os
import SwiftData

// MARK: - Dashboard Data Types

struct RecentActivityItem: Identifiable {
    let id: PersistentIdentifier
    let icon: String
    let title: String
    let subtitle: String
    let date: Date
}

struct OldestMemoItem: Identifiable {
    let id: PersistentIdentifier
    let referenceNumber: String
    let customerName: String
    let ageDays: Int
    let openAmount: Decimal
}

struct InventorySnapshot {
    var availableCount: Int = 0
    var onMemoCount: Int = 0
    var soldCount: Int = 0
    var totalCount: Int { availableCount + onMemoCount + soldCount }
}

// MARK: - ViewModel

@MainActor
@Observable
final class DashboardViewModel {
    var totalCaratsInStock: Double = 0
    var totalInventoryValue: Decimal = 0
    var totalValueOnMemo: Decimal = 0
    var monthlySales: Decimal = 0
    var recentActivity: [RecentActivityItem] = []
    var oldestOpenMemos: [OldestMemoItem] = []
    var totalOpenMemoCount: Int = 0
    var inventorySnapshot = InventorySnapshot()
    var overdueMemoCount: Int = 0
    var isLoading: Bool = false

    // MARK: - Throttle

    /// Timestamp of last full load, used for throttling.
    private var lastLoadTime: Date?
    /// Minimum interval between full reloads (avoids re-computing on rapid notifications).
    private static let minimumLoadInterval: TimeInterval = 1.0

    func load(modelContext: ModelContext) {
        // Throttle: skip reload if last load was < minimumLoadInterval ago
        if let lastLoad = lastLoadTime, Date().timeIntervalSince(lastLoad) < Self.minimumLoadInterval {
            return
        }
        isLoading = true
        defer {
            isLoading = false
            lastLoadTime = Date()
        }
        
        loadInventoryMetrics(modelContext: modelContext)
        
        // Fetch memos ONCE and reuse across all memo metrics
        let allMemos = safeFetch(FetchDescriptor<Memo>(sortBy: [SortDescriptor(\.createdAt, order: .forward)]), modelContext: modelContext)
        loadMemoMetrics(from: allMemos)
        recentActivity = buildRecentActivity(from: allMemos)
        let openMemos = allMemos.filter { $0.status == .onMemo }
        totalOpenMemoCount = openMemos.count
        oldestOpenMemos = buildOldestOpenMemos(from: allMemos)
        overdueMemoCount = openMemos.filter { $0.ageInDays > 60 }.count
        
        loadSalesMetrics(modelContext: modelContext)
    }

    // MARK: - Private

    private func loadInventoryMetrics(modelContext: ModelContext) {
        // SwiftData #Predicate does not support custom enum types as captured constants
        // ("Unsupported Predicate: Captured/constant values of type 'GemstoneStatus'").
        // Fetch all stones and filter in memory instead.
        let allStones = safeFetch(FetchDescriptor<Gemstone>(), modelContext: modelContext)

        // Single-pass: compute snapshot counts AND inventory metrics together
        var snap = InventorySnapshot()
        var carats: Double = 0
        var value: Decimal = 0

        for stone in allStones {
            switch stone.status {
            case .available:
                snap.availableCount += 1
                let effectiveCarats = stone.isLot ? stone.effectiveRemainingCarats : stone.caratWeight
                carats += effectiveCarats
                value += stone.sellPrice * Decimal(effectiveCarats)
            case .onMemo:
                snap.onMemoCount += 1
            case .sold:
                snap.soldCount += 1
            default:
                break
            }
        }
        inventorySnapshot = snap
        totalCaratsInStock = carats
        totalInventoryValue = value
    }

    private func loadMemoMetrics(from allMemos: [Memo]) {
        var memoValue: Decimal = 0
        for memo in allMemos where memo.status == .onMemo {
            memoValue += memo.openMemoAmount
        }
        totalValueOnMemo = memoValue
    }

    private func loadSalesMetrics(modelContext: ModelContext) {
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()
        let allInvoices = safeFetch(FetchDescriptor<Invoice>(), modelContext: modelContext)
        var sales: Decimal = 0
        for inv in allInvoices where (inv.status == .paid || inv.status == .sent) && inv.invoiceDate >= startOfMonth {
            sales += inv.totalAmount
        }
        monthlySales = sales
    }

    private func buildRecentActivity(from allMemos: [Memo]) -> [RecentActivityItem] {
        let memos = Array(allMemos.sorted { $0.createdAt > $1.createdAt }.prefix(8))

        return memos.map { memo in
            let customer = memo.customer?.displayName ?? "Unknown"
            let icon: String
            switch memo.status {
            case .onMemo: icon = "arrow.right.circle"
            case .returned: icon = "arrow.uturn.left.circle"
            case .sold: icon = "checkmark.circle"
            }
            return RecentActivityItem(
                id: memo.persistentModelID,
                icon: icon,
                title: "Memo #\(memo.referenceNumber)",
                subtitle: "\(customer) — \(memo.status.rawValue)",
                date: memo.createdAt
            )
        }
    }

    private func buildOldestOpenMemos(from allMemos: [Memo]) -> [OldestMemoItem] {
        let memos = Array(allMemos.filter { $0.status == .onMemo }.prefix(5))

        return memos.map { memo in
            OldestMemoItem(
                id: memo.persistentModelID,
                referenceNumber: memo.referenceNumber,
                customerName: memo.customer?.displayName ?? "Unknown",
                ageDays: memo.ageInDays,
                openAmount: memo.openMemoAmount
            )
        }
    }

    // MARK: - Helpers

    private func safeFetch<T: PersistentModel>(_ descriptor: FetchDescriptor<T>, modelContext: ModelContext) -> [T] {
        do { return try modelContext.fetch(descriptor) }
        catch {
            AppLogger.data.error("Dashboard fetch failed: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

}
