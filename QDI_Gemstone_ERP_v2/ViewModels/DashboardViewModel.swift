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

    func load(modelContext: ModelContext) {
        isLoading = true
        defer { isLoading = false }
        
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
        
        var snap = InventorySnapshot()
        snap.availableCount = allStones.filter { $0.status == .available }.count
        snap.onMemoCount = allStones.filter { $0.status == .onMemo }.count
        snap.soldCount = allStones.filter { $0.status == .sold }.count
        inventorySnapshot = snap

        let availableStones = allStones.filter { $0.status == .available }

        var carats: Double = 0
        var value: Decimal = 0
        for stone in availableStones {
            let effectiveCarats = stone.isLot ? stone.effectiveRemainingCarats : stone.caratWeight
            carats += effectiveCarats
            value += stone.sellPrice * Decimal(effectiveCarats)
        }
        totalCaratsInStock = carats
        totalInventoryValue = value
    }

    private func loadMemoMetrics(from allMemos: [Memo]) {
        let openMemos = allMemos.filter { $0.status == .onMemo }
        totalValueOnMemo = openMemos.reduce(Decimal.zero) { $0 + $1.openMemoAmount }
    }

    private func loadSalesMetrics(modelContext: ModelContext) {
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()
        let allInvoices = safeFetch(FetchDescriptor<Invoice>(), modelContext: modelContext)
        let periodInvoices = allInvoices.filter {
            ($0.status == .paid || $0.status == .sent) && $0.invoiceDate >= startOfMonth
        }
        monthlySales = periodInvoices.reduce(Decimal.zero) { $0 + $1.totalAmount }
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
