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
    var inventorySnapshot = InventorySnapshot()
    var overdueMemoCount: Int = 0
    var isLoading: Bool = false

    func load(modelContext: ModelContext) {
        isLoading = true
        defer { isLoading = false }
        loadInventoryMetrics(modelContext: modelContext)
        loadMemoMetrics(modelContext: modelContext)
        loadSalesMetrics(modelContext: modelContext)
        recentActivity = fetchRecentActivity(modelContext: modelContext)
        oldestOpenMemos = fetchOldestOpenMemos(modelContext: modelContext)
        loadOverdueMemoCount(modelContext: modelContext)
    }

    // MARK: - Private

    private func loadInventoryMetrics(modelContext: ModelContext) {
        // Use fetchCount for snapshot counts instead of fetching all records
        var snap = InventorySnapshot()
        let availableStatus = GemstoneStatus.available
        let onMemoStatus = GemstoneStatus.onMemo
        let soldStatus = GemstoneStatus.sold
        snap.availableCount = safeCount(FetchDescriptor<Gemstone>(
            predicate: #Predicate<Gemstone> { $0.status == availableStatus }
        ), modelContext: modelContext)
        snap.onMemoCount = safeCount(FetchDescriptor<Gemstone>(
            predicate: #Predicate<Gemstone> { $0.status == onMemoStatus }
        ), modelContext: modelContext)
        snap.soldCount = safeCount(FetchDescriptor<Gemstone>(
            predicate: #Predicate<Gemstone> { $0.status == soldStatus }
        ), modelContext: modelContext)
        inventorySnapshot = snap

        // Fetch only available stones for carats/value calculation
        let availableDesc = FetchDescriptor<Gemstone>(
            predicate: #Predicate<Gemstone> { $0.status == availableStatus }
        )
        let availableStones = safeFetch(availableDesc, modelContext: modelContext)

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

    private func loadMemoMetrics(modelContext: ModelContext) {
        let onMemoStatus = MemoStatus.onMemo
        let descriptor = FetchDescriptor<Memo>(
            predicate: #Predicate<Memo> { $0.status == onMemoStatus }
        )
        let memos = safeFetch(descriptor, modelContext: modelContext)
        totalValueOnMemo = memos.reduce(Decimal.zero) { $0 + $1.openMemoAmount }
    }

    private func loadSalesMetrics(modelContext: ModelContext) {
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()
        let paidStatus = InvoiceStatus.paid
        let sentStatus = InvoiceStatus.sent
        let descriptor = FetchDescriptor<Invoice>(
            predicate: #Predicate<Invoice> {
                ($0.status == paidStatus || $0.status == sentStatus) &&
                $0.invoiceDate >= startOfMonth
            }
        )
        let invoices = safeFetch(descriptor, modelContext: modelContext)
        monthlySales = invoices.reduce(Decimal.zero) { $0 + $1.totalAmount }
    }

    private func fetchRecentActivity(modelContext: ModelContext) -> [RecentActivityItem] {
        var descriptor = FetchDescriptor<Memo>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 8
        let memos = safeFetch(descriptor, modelContext: modelContext)

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

    private func fetchOldestOpenMemos(modelContext: ModelContext) -> [OldestMemoItem] {
        let onMemoStatus = MemoStatus.onMemo
        var descriptor = FetchDescriptor<Memo>(
            predicate: #Predicate<Memo> { $0.status == onMemoStatus },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        descriptor.fetchLimit = 5
        let memos = safeFetch(descriptor, modelContext: modelContext)

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

    private func loadOverdueMemoCount(modelContext: ModelContext) {
        let onMemoStatus = MemoStatus.onMemo
        let descriptor = FetchDescriptor<Memo>(
            predicate: #Predicate<Memo> { $0.status == onMemoStatus }
        )
        let memos = safeFetch(descriptor, modelContext: modelContext)
        overdueMemoCount = memos.filter { $0.ageInDays > 60 }.count
    }

    // MARK: - Helpers

    private func safeFetch<T: PersistentModel>(_ descriptor: FetchDescriptor<T>, modelContext: ModelContext) -> [T] {
        do { return try modelContext.fetch(descriptor) }
        catch { AppLogger.data.error("Dashboard fetch failed: \(error.localizedDescription, privacy: .public)"); return [] }
    }

    private func safeCount<T: PersistentModel>(_ descriptor: FetchDescriptor<T>, modelContext: ModelContext) -> Int {
        do { return try modelContext.fetchCount(descriptor) }
        catch { AppLogger.data.error("Dashboard count failed: \(error.localizedDescription, privacy: .public)"); return 0 }
    }
}
