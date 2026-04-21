import Foundation
import SwiftData
import os

// MARK: - Data Types

enum AccountingDateRange: Hashable {
    case allTime
    case thisYear
    case last12Months
    case thisMonth
    case thisQuarter
    case thisWeek
    case custom(from: Date, to: Date)

    var displayName: String {
        switch self {
        case .allTime: return "All Time"
        case .thisYear: return "This Year"
        case .last12Months: return "Last 12 Months"
        case .thisMonth: return "This Month"
        case .thisQuarter: return "This Quarter"
        case .thisWeek: return "This Week"
        case .custom: return "Custom"
        }
    }

    /// All fixed (non-custom) cases for the picker.
    static var pickerCases: [AccountingDateRange] {
        [.allTime, .thisWeek, .thisMonth, .thisQuarter, .thisYear, .last12Months, .custom(from: Date(), to: Date())]
    }

    /// Whether this is a custom range (for showing date pickers).
    var isCustom: Bool {
        if case .custom = self { return true }
        return false
    }

    var startDate: Date? {
        let calendar = Calendar.current
        let now = Date()
        switch self {
        case .allTime: return nil
        case .thisYear:
            return calendar.date(from: calendar.dateComponents([.year], from: now))
        case .last12Months:
            return calendar.date(byAdding: .month, value: -12, to: now)
        case .thisMonth:
            return calendar.date(from: calendar.dateComponents([.year, .month], from: now))
        case .thisQuarter:
            let month = calendar.component(.month, from: now)
            let quarterStartMonth = ((month - 1) / 3) * 3 + 1
            var components = calendar.dateComponents([.year], from: now)
            components.month = quarterStartMonth
            components.day = 1
            return calendar.date(from: components)
        case .thisWeek:
            return calendar.dateInterval(of: .weekOfYear, for: now)?.start
        case .custom(let from, _):
            return from
        }
    }

    var endDate: Date? {
        switch self {
        case .custom(_, let to): return to
        default: return nil
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
    var cost: Decimal = 0
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
    var isLoading: Bool = false

    func load(modelContext: ModelContext) {
        isLoading = true
        defer { isLoading = false }

        // SwiftData #Predicate does not support custom enum types as captured constants.
        // Fetch all invoices and filter in memory instead.
        let descriptor = FetchDescriptor<Invoice>()
        let allInvoices: [Invoice]
        do {
            allInvoices = try modelContext.fetch(descriptor)
                .filter { $0.status == .paid || $0.status == .sent }
        } catch {
            AppLogger.data.error("Accounting fetch failed: \(error.localizedDescription, privacy: .public)")
            allInvoices = []
        }

        // Date-filtered subset for revenue/cost/breakdown
        let startDate = dateRange.startDate
        let endDate = dateRange.endDate
        let filtered = allInvoices.filter { inv in
            if let start = startDate, inv.invoiceDate < start { return false }
            if let end = endDate, inv.invoiceDate > end { return false }
            return true
        }
        computeAll(from: filtered)

        // Aged receivables from sent-only (all time, not date-filtered)
        let sentInvoices = allInvoices.filter { $0.status == .sent }
        computeAgedReceivables(from: sentInvoices)
    }

    // MARK: - CSV Export

    func exportCSV() -> String {
        var lines = ["Month,Revenue,Cost,Profit"]
        for row in monthlySales {
            lines.append("\(row.month),\(row.revenue),\(row.cost),\(row.revenue - row.cost)")
        }
        lines.append("")
        lines.append("Total Revenue,\(totalRevenue)")
        lines.append("Total Cost,\(totalCost)")
        lines.append("Total Profit,\(totalProfit)")
        return lines.joined(separator: "\n")
    }

    // MARK: - Private

    /// Single-pass aggregation: revenue, cost, stone type breakdown, and monthly sales.
    private func computeAll(from invoices: [Invoice]) {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM"

        var revenue: Decimal = 0
        var cost: Decimal = 0
        var stoneTypeMap: [String: Decimal] = [:]
        var monthlyRevenueMap: [String: Decimal] = [:]
        var monthlyCostMap: [String: Decimal] = [:]

        for inv in invoices {
            revenue += inv.totalAmount
            let monthKey = fmt.string(from: inv.invoiceDate)
            monthlyRevenueMap[monthKey, default: 0] += inv.totalAmount

            for item in inv.lineItems {
                stoneTypeMap[item.stoneTypeDisplay, default: 0] += item.amount
                var itemCost: Decimal = 0
                if let stone = item.gemstone {
                    if item.isLotLineItem {
                        itemCost = (item.lockedCostPerCarat ?? stone.effectiveAverageCost) * Decimal(item.carats)
                    } else {
                        itemCost = stone.costPrice
                    }
                    cost += itemCost
                    monthlyCostMap[monthKey, default: 0] += itemCost
                }
            }
        }

        totalRevenue = revenue
        totalCost = cost
        salesByStoneType = stoneTypeMap.map { SalesByStoneType(id: $0.key, stoneType: $0.key, revenue: $0.value) }
            .sorted { $0.revenue > $1.revenue }
        monthlySales = monthlyRevenueMap.map {
            MonthlySales(id: $0.key, month: $0.key, revenue: $0.value, cost: monthlyCostMap[$0.key] ?? 0)
        }.sorted { $0.id < $1.id }
    }

    /// Compute aged receivables from pre-fetched sent invoices (no additional DB fetch).
    private func computeAgedReceivables(from sentInvoices: [Invoice]) {
        var buckets = [
            AgedReceivableBucket(id: "0-30", label: "0–30 days"),
            AgedReceivableBucket(id: "31-60", label: "31–60 days"),
            AgedReceivableBucket(id: "61-90", label: "61–90 days"),
            AgedReceivableBucket(id: "90+", label: "90+ days"),
        ]

        let today = Date()
        let calendar = Calendar.current
        for inv in sentInvoices {
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
}
