import Foundation
import SwiftData

// MARK: - Data Types

enum AccountingDateRange: String, CaseIterable {
    case allTime = "All Time"
    case thisYear = "This Year"
    case last12Months = "Last 12 Months"

    var startDate: Date? {
        let calendar = Calendar.current
        switch self {
        case .allTime: return nil
        case .thisYear:
            return calendar.date(from: calendar.dateComponents([.year], from: Date()))
        case .last12Months:
            return calendar.date(byAdding: .month, value: -12, to: Date())
        }
    }
}

struct AgedReceivableBucket: Identifiable {
    let id: String
    let label: String
    var amount: Decimal = 0
    var count: Int = 0
}

struct SalesByStoneType: Identifiable {
    let id: String
    let stoneType: String
    var revenue: Decimal = 0
}

struct MonthlySales: Identifiable {
    let id: String // "YYYY-MM"
    let month: String
    var revenue: Decimal = 0
}

// MARK: - ViewModel

@MainActor
@Observable
final class AccountingViewModel {
    var dateRange: AccountingDateRange = .last12Months

    var totalRevenue: Decimal = 0
    var totalCost: Decimal = 0
    var totalProfit: Decimal { totalRevenue - totalCost }
    var profitMargin: Double {
        guard totalRevenue > 0 else { return 0 }
        return NSDecimalNumber(decimal: totalProfit / totalRevenue * 100).doubleValue
    }

    var agedReceivables: [AgedReceivableBucket] = []
    var salesByStoneType: [SalesByStoneType] = []
    var monthlySales: [MonthlySales] = []

    func load(modelContext: ModelContext) {
        let startDate = dateRange.startDate
        loadRevenueAndCost(startDate: startDate, modelContext: modelContext)
        loadAgedReceivables(modelContext: modelContext)
        loadSalesByStoneType(startDate: startDate, modelContext: modelContext)
        loadMonthlySales(startDate: startDate, modelContext: modelContext)
    }

    // MARK: - CSV Export

    func exportCSV() -> String {
        var lines = ["Month,Revenue"]
        for row in monthlySales {
            lines.append("\(row.month),\(row.revenue)")
        }
        lines.append("")
        lines.append("Total Revenue,\(totalRevenue)")
        lines.append("Total Cost,\(totalCost)")
        lines.append("Total Profit,\(totalProfit)")
        return lines.joined(separator: "\n")
    }

    // MARK: - Private

    private func loadRevenueAndCost(startDate: Date?, modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Invoice>()
        guard let invoices = try? modelContext.fetch(descriptor) else {
            totalRevenue = 0; totalCost = 0; return
        }

        let filtered = invoices.filter { inv in
            guard inv.status == .paid || inv.status == .sent else { return false }
            if let start = startDate { return inv.invoiceDate >= start }
            return true
        }

        totalRevenue = filtered.reduce(Decimal.zero) { $0 + $1.totalAmount }

        totalCost = filtered.reduce(Decimal.zero) { sum, inv in
            sum + inv.lineItems.reduce(Decimal.zero) { lineSum, item in
                if let stone = item.gemstone {
                    if item.isLotLineItem {
                        return lineSum + (item.lockedCostPerCarat ?? stone.effectiveAverageCost) * Decimal(item.carats)
                    }
                    return lineSum + stone.costPrice
                }
                return lineSum
            }
        }
    }

    private func loadAgedReceivables(modelContext: ModelContext) {
        let sentStatus = InvoiceStatus.sent
        let descriptor = FetchDescriptor<Invoice>(
            predicate: #Predicate<Invoice> { $0.status == sentStatus }
        )
        guard let invoices = try? modelContext.fetch(descriptor) else {
            agedReceivables = []; return
        }

        var buckets = [
            AgedReceivableBucket(id: "0-30", label: "0–30 days"),
            AgedReceivableBucket(id: "31-60", label: "31–60 days"),
            AgedReceivableBucket(id: "61-90", label: "61–90 days"),
            AgedReceivableBucket(id: "90+", label: "90+ days"),
        ]

        let today = Date()
        let calendar = Calendar.current
        for inv in invoices {
            let days = calendar.dateComponents([.day], from: inv.invoiceDate, to: today).day ?? 0
            let idx: Int
            switch days {
            case 0...30: idx = 0
            case 31...60: idx = 1
            case 61...90: idx = 2
            default: idx = 3
            }
            buckets[idx].amount += inv.totalAmount
            buckets[idx].count += 1
        }

        agedReceivables = buckets
    }

    private func loadSalesByStoneType(startDate: Date?, modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Invoice>()
        guard let invoices = try? modelContext.fetch(descriptor) else {
            salesByStoneType = []; return
        }

        var map: [String: Decimal] = [:]
        for inv in invoices {
            guard inv.status == .paid || inv.status == .sent else { continue }
            if let start = startDate, inv.invoiceDate < start { continue }
            for item in inv.lineItems {
                let type = item.stoneTypeDisplay
                map[type, default: 0] += item.amount
            }
        }

        salesByStoneType = map.map { SalesByStoneType(id: $0.key, stoneType: $0.key, revenue: $0.value) }
            .sorted { $0.revenue > $1.revenue }
    }

    private func loadMonthlySales(startDate: Date?, modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Invoice>()
        guard let invoices = try? modelContext.fetch(descriptor) else {
            monthlySales = []; return
        }

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM"

        var map: [String: Decimal] = [:]
        for inv in invoices {
            guard inv.status == .paid || inv.status == .sent else { continue }
            if let start = startDate, inv.invoiceDate < start { continue }
            let key = fmt.string(from: inv.invoiceDate)
            map[key, default: 0] += inv.totalAmount
        }

        monthlySales = map.map { MonthlySales(id: $0.key, month: $0.key, revenue: $0.value) }
            .sorted { $0.id < $1.id }
    }
}
