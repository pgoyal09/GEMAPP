import Foundation
import SwiftData

@MainActor
@Observable
final class AccountingViewModel {
    var dateRangeOption: AccountingView.DateRangeOption = .allTime

    private(set) var totalRevenue: Decimal = 0
    private(set) var totalCost: Decimal = 0
    var totalProfit: Decimal { totalRevenue - totalCost }

    private(set) var salesByMonth: [(month: String, amount: Decimal)] = []
    private(set) var salesByStoneType: [(type: String, amount: Decimal)] = []
    private(set) var agedReceivables: (current: Decimal, days31_60: Decimal, days61_90: Decimal, over90: Decimal) = (0, 0, 0, 0)

    func load(invoices: [Invoice]) {
        let paidOrSent = filteredInvoices(from: invoices)
        let open = invoices.filter { $0.effectiveStatus == .sent }

        totalRevenue = paidOrSent.reduce(Decimal(0)) { $0 + $1.totalAmount }
        totalCost = paidOrSent.reduce(Decimal(0)) { sum, inv in
            sum + inv.lineItems.reduce(Decimal(0)) { lineSum, item in
                if let stone = item.gemstone {
                    return lineSum + stone.costPrice * Decimal(item.carats)
                }
                return lineSum
            }
        }

        computeSalesByMonth(from: paidOrSent)
        computeSalesByStoneType(from: paidOrSent)
        computeAgedReceivables(from: open)
    }

    func exportCSVContent() -> String {
        let header = "Month,Revenue\n"
        let rows = salesByMonth.map { "\($0.month),\($0.amount)" }.joined(separator: "\n")
        let summary = "\n\nSummary\nTotal Revenue,\(totalRevenue)\nTotal Cost,\(totalCost)\nTotal Profit,\(totalProfit)\n"
        return header + rows + summary
    }

    // MARK: - Private

    private func filteredInvoices(from allInvoices: [Invoice]) -> [Invoice] {
        let cal = Calendar.current
        let now = Date()
        let dateRange: (start: Date?, end: Date?) = {
            switch dateRangeOption {
            case .allTime: return (nil, nil)
            case .thisYear: return (cal.date(from: cal.dateComponents([.year], from: now)), now)
            case .last12Months: return (cal.date(byAdding: .month, value: -12, to: now), now)
            }
        }()

        return allInvoices
            .filter { $0.effectiveStatus == .paid || $0.effectiveStatus == .sent }
            .filter { inv in
                if let s = dateRange.start, inv.invoiceDate < s { return false }
                if let e = dateRange.end, inv.invoiceDate > e { return false }
                return true
            }
    }

    private func computeSalesByMonth(from invoices: [Invoice]) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        var dict: [String: Decimal] = [:]
        for inv in invoices {
            let key = formatter.string(from: inv.invoiceDate)
            dict[key, default: 0] += inv.totalAmount
        }
        salesByMonth = dict.sorted { $0.key > $1.key }.map { (month: $0.key, amount: $0.value) }
    }

    private func computeSalesByStoneType(from invoices: [Invoice]) {
        var dict: [String: Decimal] = [:]
        for inv in invoices {
            for item in inv.lineItems {
                let typeStr = item.gemstone?.stoneType.rawValue ?? (item.isService ? "Service" : "Other")
                dict[typeStr, default: 0] += item.amount
            }
        }
        salesByStoneType = dict.sorted { $0.value > $1.value }.map { (type: $0.key, amount: $0.value) }
    }

    private func computeAgedReceivables(from openInvoices: [Invoice]) {
        let now = Date()
        var current = Decimal(0), d31_60 = Decimal(0), d61_90 = Decimal(0), over90 = Decimal(0)
        for inv in openInvoices {
            let days = Calendar.current.dateComponents([.day], from: inv.invoiceDate, to: now).day ?? 0
            let amt = inv.totalAmount
            if days <= 30 { current += amt }
            else if days <= 60 { d31_60 += amt }
            else if days <= 90 { d61_90 += amt }
            else { over90 += amt }
        }
        agedReceivables = (current, d31_60, d61_90, over90)
    }
}
