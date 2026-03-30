import Foundation
import SwiftData

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
        let startDate = dateRange.startDate
        let endDate = dateRange.endDate
        loadRevenueAndCost(startDate: startDate, endDate: endDate, modelContext: modelContext)
        loadAgedReceivables(modelContext: modelContext)
        loadSalesByStoneType(startDate: startDate, endDate: endDate, modelContext: modelContext)
        loadMonthlySales(startDate: startDate, endDate: endDate, modelContext: modelContext)
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

    private func loadRevenueAndCost(startDate: Date?, endDate: Date? = nil, modelContext: ModelContext) {
        let filtered = fetchFilteredInvoices(startDate: startDate, endDate: endDate, modelContext: modelContext)
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

    /// Shared helper to fetch paid/sent invoices within a date range.
    private func fetchFilteredInvoices(startDate: Date?, endDate: Date? = nil, modelContext: ModelContext) -> [Invoice] {
        let paidStatus = InvoiceStatus.paid
        let sentStatus = InvoiceStatus.sent
        let descriptor: FetchDescriptor<Invoice>
        if let start = startDate, let end = endDate {
            descriptor = FetchDescriptor<Invoice>(
                predicate: #Predicate<Invoice> {
                    ($0.status == paidStatus || $0.status == sentStatus) &&
                    $0.invoiceDate >= start && $0.invoiceDate <= end
                }
            )
        } else if let start = startDate {
            descriptor = FetchDescriptor<Invoice>(
                predicate: #Predicate<Invoice> {
                    ($0.status == paidStatus || $0.status == sentStatus) &&
                    $0.invoiceDate >= start
                }
            )
        } else {
            descriptor = FetchDescriptor<Invoice>(
                predicate: #Predicate<Invoice> {
                    $0.status == paidStatus || $0.status == sentStatus
                }
            )
        }
        return (try? modelContext.fetch(descriptor)) ?? []
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

    private func loadSalesByStoneType(startDate: Date?, endDate: Date? = nil, modelContext: ModelContext) {
        let invoices = fetchFilteredInvoices(startDate: startDate, endDate: endDate, modelContext: modelContext)

        var map: [String: Decimal] = [:]
        for inv in invoices {
            for item in inv.lineItems {
                let type = item.stoneTypeDisplay
                map[type, default: 0] += item.amount
            }
        }

        salesByStoneType = map.map { SalesByStoneType(id: $0.key, stoneType: $0.key, revenue: $0.value) }
            .sorted { $0.revenue > $1.revenue }
    }

    private func loadMonthlySales(startDate: Date?, endDate: Date? = nil, modelContext: ModelContext) {
        let invoices = fetchFilteredInvoices(startDate: startDate, endDate: endDate, modelContext: modelContext)

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM"

        var map: [String: Decimal] = [:]
        for inv in invoices {
            let key = fmt.string(from: inv.invoiceDate)
            map[key, default: 0] += inv.totalAmount
        }

        monthlySales = map.map { MonthlySales(id: $0.key, month: $0.key, revenue: $0.value) }
            .sorted { $0.id < $1.id }
    }
}
