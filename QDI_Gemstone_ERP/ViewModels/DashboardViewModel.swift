import Foundation
import SwiftData

/// One row in recent activity; uses memo id so ForEach has unique IDs (display titles can duplicate).
struct RecentActivityItem: Identifiable {
    let id: PersistentIdentifier
    let title: String
}

/// Memo row for Oldest Open Memos list in info panel.
struct OldestMemoItem: Identifiable {
    let id: PersistentIdentifier
    let referenceNumber: String?
    let customerName: String
    let ageDays: Int
    let totalAmount: Decimal
    let status: MemoStatus
    let memo: Memo
}

/// Inventory snapshot counts for info panel.
struct InventorySnapshot {
    var availableCount: Int = 0
    var onMemoCount: Int = 0
    var soldCount: Int = 0
}

@MainActor
@Observable
final class DashboardViewModel {
    var totalCaratsInStock: Double = 0
    var totalValueOnMemo: Decimal = 0
    var recentActivity: [RecentActivityItem] = []
    var oldestOpenMemos: [OldestMemoItem] = []
    var inventorySnapshot: InventorySnapshot = InventorySnapshot()

    func load(modelContext: ModelContext) {
        totalCaratsInStock = calculateTotalCaratsInStock(modelContext: modelContext)
        totalValueOnMemo = calculateTotalValueOnMemo(modelContext: modelContext)
        recentActivity = fetchRecentActivity(modelContext: modelContext)
        oldestOpenMemos = fetchOldestOpenMemos(modelContext: modelContext)
        inventorySnapshot = fetchInventorySnapshot(modelContext: modelContext)
    }

    private func calculateTotalCaratsInStock(modelContext: ModelContext) -> Double {
        let descriptor = FetchDescriptor<Gemstone>()
        guard let gemstones = try? modelContext.fetch(descriptor) else { return 0 }

        let onMemoStatus = MemoStatus.onMemo
        let memoDescriptor = FetchDescriptor<Memo>(
            predicate: #Predicate<Memo> { $0.status == onMemoStatus }
        )
        guard let onMemo = try? modelContext.fetch(memoDescriptor) else {
            return gemstones.reduce(0) { $0 + $1.caratWeight }
        }

        let onMemoStoneIDs = Set(onMemo.flatMap { $0.lineItems.compactMap(\.gemstone).map(\.sku) })
        return gemstones
            .filter { !onMemoStoneIDs.contains($0.sku) }
            .reduce(0) { $0 + $1.caratWeight }
    }

    private func calculateTotalValueOnMemo(modelContext: ModelContext) -> Decimal {
        let onMemoStatus = MemoStatus.onMemo
        let descriptor = FetchDescriptor<Memo>(
            predicate: #Predicate<Memo> { $0.status == onMemoStatus }
        )
        guard let memos = try? modelContext.fetch(descriptor) else { return 0 }

        return memos.flatMap { memo in
            memo.openLineItems.map { item in
                item.gemstone?.sellPrice ?? item.amount
            }
        }.reduce(0, +)
    }

    private func fetchRecentActivity(modelContext: ModelContext) -> [RecentActivityItem] {
        var descriptor = FetchDescriptor<Memo>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 5

        guard let memos = try? modelContext.fetch(descriptor) else { return [] }

        let formatter = DateFormatter()
        formatter.dateStyle = .short

        return memos.map { memo in
            let customer = memo.customer?.displayName ?? "Unknown"
            let date = memo.dateAssigned.map { formatter.string(from: $0) } ?? "-"
            let ref = memo.referenceNumber.map { "#\($0) " } ?? ""
            let title = "Memo \(ref)– \(customer) (\(memo.status.rawValue)) - \(date)"
            return RecentActivityItem(id: memo.id, title: title)
        }
    }

    private func fetchOldestOpenMemos(modelContext: ModelContext) -> [OldestMemoItem] {
        var descriptor = FetchDescriptor<Memo>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        descriptor.fetchLimit = 50
        guard let allMemos = try? modelContext.fetch(descriptor) else { return [] }
        let openMemos = Array(allMemos.filter { $0.status == .onMemo }.prefix(5))
        let calendar = Calendar.current
        let today = Date()

        return openMemos.map { memo in
            let customer = memo.customer?.displayName ?? "Unknown"
            let ageDays = calendar.dateComponents([.day], from: memo.createdAt, to: today).day ?? 0
            return OldestMemoItem(
                id: memo.id,
                referenceNumber: memo.referenceNumber,
                customerName: customer,
                ageDays: ageDays,
                totalAmount: memo.totalAmount,
                status: memo.status,
                memo: memo
            )
        }
    }

    private func fetchInventorySnapshot(modelContext: ModelContext) -> InventorySnapshot {
        let descriptor = FetchDescriptor<Gemstone>()
        guard let gemstones = try? modelContext.fetch(descriptor) else {
            return InventorySnapshot()
        }
        var snap = InventorySnapshot()
        for g in gemstones {
            switch g.effectiveStatus {
            case .available: snap.availableCount += 1
            case .onMemo: snap.onMemoCount += 1
            case .sold: snap.soldCount += 1
            }
        }
        return snap
    }
}
