import Foundation
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

    func load(modelContext: ModelContext) {
        loadInventoryMetrics(modelContext: modelContext)
        loadMemoMetrics(modelContext: modelContext)
        loadSalesMetrics(modelContext: modelContext)
        recentActivity = fetchRecentActivity(modelContext: modelContext)
        oldestOpenMemos = fetchOldestOpenMemos(modelContext: modelContext)
    }

    // MARK: - Private

    private func loadInventoryMetrics(modelContext: ModelContext) {
        // Use fetchCount for snapshot counts instead of fetching all records
        var snap = InventorySnapshot()
        let availableStatus = GemstoneStatus.available
        let onMemoStatus = GemstoneStatus.onMemo
        let soldStatus = GemstoneStatus.sold
        snap.availableCount = (try? modelContext.fetchCount(FetchDescriptor<Gemstone>(
            predicate: #Predicate<Gemstone> { $0.status == availableStatus }
        ))) ?? 0
        snap.onMemoCount = (try? modelContext.fetchCount(FetchDescriptor<Gemstone>(
            predicate: #Predicate<Gemstone> { $0.status == onMemoStatus }
        ))) ?? 0
        snap.soldCount = (try? modelContext.fetchCount(FetchDescriptor<Gemstone>(
            predicate: #Predicate<Gemstone> { $0.status == soldStatus }
        ))) ?? 0
        inventorySnapshot = snap

        // Fetch only available stones for carats/value calculation
        let availableDesc = FetchDescriptor<Gemstone>(
            predicate: #Predicate<Gemstone> { $0.status == availableStatus }
        )
        guard let availableStones = try? modelContext.fetch(availableDesc) else {
            totalCaratsInStock = 0
            totalInventoryValue = 0
            return
        }

        var carats: Double = 0
        var value: Decimal = 0
        for stone in availableStones {
            carats += stone.isLot ? stone.effectiveRemainingCarats : stone.caratWeight
            value += stone.sellPrice * Decimal(stone.caratWeight)
        }
        totalCaratsInStock = carats
        totalInventoryValue = value
    }

    private func loadMemoMetrics(modelContext: ModelContext) {
        let onMemoStatus = MemoStatus.onMemo
        let descriptor = FetchDescriptor<Memo>(
            predicate: #Predicate<Memo> { $0.status == onMemoStatus }
        )
        guard let memos = try? modelContext.fetch(descriptor) else {
            totalValueOnMemo = 0
            return
        }
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
        guard let invoices = try? modelContext.fetch(descriptor) else {
            monthlySales = 0
            return
        }
        monthlySales = invoices.reduce(Decimal.zero) { $0 + $1.totalAmount }
    }

    private func fetchRecentActivity(modelContext: ModelContext) -> [RecentActivityItem] {
        var descriptor = FetchDescriptor<Memo>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 8
        guard let memos = try? modelContext.fetch(descriptor) else { return [] }

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
        guard let memos = try? modelContext.fetch(descriptor) else { return [] }

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
}
