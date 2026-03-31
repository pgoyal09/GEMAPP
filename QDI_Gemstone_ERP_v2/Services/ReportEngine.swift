import Foundation
import SwiftData

// MARK: - Report Data Models

struct PLRow: Identifiable {
    let id = UUID()
    let stoneType: String
    let unitsSold: Int
    let revenue: Decimal
    let cogs: Decimal
    var grossProfit: Decimal { revenue - cogs }
    var marginPercent: Double {
        guard revenue > 0 else { return 0 }
        return (NSDecimalNumber(decimal: grossProfit).doubleValue / NSDecimalNumber(decimal: revenue).doubleValue) * 100
    }
}

struct PLReport {
    let revenue: Decimal
    let cogs: Decimal
    var grossProfit: Decimal { revenue - cogs }
    var marginPercent: Double {
        guard revenue > 0 else { return 0 }
        return (NSDecimalNumber(decimal: grossProfit).doubleValue / NSDecimalNumber(decimal: revenue).doubleValue) * 100
    }
    let breakdownByType: [PLRow]
}

struct InventoryTurnoverReport {
    let currentCount: Int
    let currentValue: Decimal
    let soldCount: Int
    let soldValue: Decimal
    let turnoverRate: Double
    let agingBuckets: [AgingBucket]
    let slowMovers: [SlowMover]
}

struct AgingBucket: Identifiable {
    let id = UUID()
    let label: String
    let count: Int
    let value: Decimal
}

struct SlowMover: Identifiable {
    let id = UUID()
    let sku: String
    let stoneType: String
    let caratWeight: Double
    let costPrice: Decimal
    let daysInInventory: Int
}

struct CustomerProfitRow: Identifiable {
    let id = UUID()
    let customerName: String
    let customerId: PersistentIdentifier?
    let totalRevenue: Decimal
    let totalCOGS: Decimal
    var profit: Decimal { totalRevenue - totalCOGS }
    var marginPercent: Double {
        guard totalRevenue > 0 else { return 0 }
        return (NSDecimalNumber(decimal: profit).doubleValue / NSDecimalNumber(decimal: totalRevenue).doubleValue) * 100
    }
    let transactionCount: Int
    var avgOrderValue: Decimal {
        guard transactionCount > 0 else { return 0 }
        return totalRevenue / Decimal(transactionCount)
    }
}

struct CustomerProfitabilityReport {
    let rows: [CustomerProfitRow]
}

struct MonthlyMargin: Identifiable {
    let id = UUID()
    let month: String
    let marginPercent: Double
    let revenue: Decimal
    let cogs: Decimal
}

struct StoneTypeMargin: Identifiable {
    let id = UUID()
    let stoneType: String
    let avgMarginPercent: Double
    let count: Int
}

struct MarginBucket: Identifiable {
    let id = UUID()
    let label: String
    let count: Int
    var percent: Double = 0
}

struct MarginAnalysisReport {
    let monthlyTrend: [MonthlyMargin]
    let byStoneType: [StoneTypeMargin]
    let distribution: [MarginBucket]
}

// MARK: - Report Engine

enum ReportEngine {

    // MARK: - P&L Report

    @MainActor
    static func generatePLReport(
        startDate: Date,
        endDate: Date,
        modelContext: ModelContext
    ) -> PLReport {
        let paidStatus = InvoiceStatus.paid
        let descriptor = FetchDescriptor<Invoice>(
            predicate: #Predicate<Invoice> { $0.status == paidStatus }
        )
        let invoices = (try? modelContext.fetch(descriptor)) ?? []
        let filtered = invoices.filter { $0.invoiceDate >= startDate && $0.invoiceDate <= endDate }

        var typeMap: [String: (units: Int, revenue: Decimal, cogs: Decimal)] = [:]

        for invoice in filtered {
            for item in invoice.lineItems {
                guard item.status == .sold else { continue }
                let type = item.gemstone?.stoneType.rawValue.capitalized ?? item.stoneTypeDisplay
                let revenue = item.netAmount
                let cogs: Decimal
                if item.isLotLineItem, let locked = item.lockedCostPerCarat {
                    cogs = locked * Decimal(item.carats)
                } else {
                    cogs = item.gemstone?.costPrice ?? 0
                }
                var entry = typeMap[type, default: (0, 0, 0)]
                entry.units += 1
                entry.revenue += revenue
                entry.cogs += cogs
                typeMap[type] = entry
            }
        }

        let rows = typeMap.map { PLRow(stoneType: $0.key, unitsSold: $0.value.units, revenue: $0.value.revenue, cogs: $0.value.cogs) }
            .sorted { $0.revenue > $1.revenue }

        let totalRevenue = rows.reduce(Decimal.zero) { $0 + $1.revenue }
        let totalCOGS = rows.reduce(Decimal.zero) { $0 + $1.cogs }

        return PLReport(revenue: totalRevenue, cogs: totalCOGS, breakdownByType: rows)
    }

    // MARK: - Inventory Turnover

    @MainActor
    static func generateInventoryTurnover(
        startDate: Date,
        endDate: Date,
        modelContext: ModelContext
    ) -> InventoryTurnoverReport {
        let availableStatus = GemstoneStatus.available
        let allDescriptor = FetchDescriptor<Gemstone>(
            predicate: #Predicate<Gemstone> { $0.status == availableStatus }
        )
        let available = (try? modelContext.fetch(allDescriptor)) ?? []
        let currentCount = available.count
        let currentValue = available.reduce(Decimal.zero) { $0 + $1.costPrice }

        let soldStatus = GemstoneStatus.sold
        let soldDescriptor = FetchDescriptor<Gemstone>(
            predicate: #Predicate<Gemstone> { $0.status == soldStatus }
        )
        _ = (try? modelContext.fetch(soldDescriptor)) ?? [] // available for future use

        let paidStatus = InvoiceStatus.paid
        let invDescriptor = FetchDescriptor<Invoice>(
            predicate: #Predicate<Invoice> { $0.status == paidStatus }
        )
        let invoices = (try? modelContext.fetch(invDescriptor)) ?? []
        let periodInvoices = invoices.filter { $0.invoiceDate >= startDate && $0.invoiceDate <= endDate }

        var soldCount = 0
        var soldValue: Decimal = 0
        for inv in periodInvoices {
            for item in inv.lineItems where item.status == .sold {
                soldCount += 1
                if item.isLotLineItem, let locked = item.lockedCostPerCarat {
                    soldValue += locked * Decimal(item.carats)
                } else {
                    soldValue += item.gemstone?.costPrice ?? 0
                }
            }
        }

        let avgInventory = currentValue > 0 ? currentValue : 1
        let turnoverRate = soldValue > 0 ? NSDecimalNumber(decimal: soldValue / avgInventory).doubleValue : 0

        // Aging buckets
        let today = Date()
        let calendar = Calendar.current
        var b030 = 0, b3160 = 0, b6190 = 0, b91180 = 0, b180plus = 0
        var v030: Decimal = 0, v3160: Decimal = 0, v6190: Decimal = 0, v91180: Decimal = 0, v180plus: Decimal = 0

        for stone in available {
            let days = calendar.dateComponents([.day], from: stone.createdAt, to: today).day ?? 0
            switch days {
            case 0...30:
                b030 += 1; v030 += stone.costPrice
            case 31...60:
                b3160 += 1; v3160 += stone.costPrice
            case 61...90:
                b6190 += 1; v6190 += stone.costPrice
            case 91...180:
                b91180 += 1; v91180 += stone.costPrice
            default:
                b180plus += 1; v180plus += stone.costPrice
            }
        }

        let buckets = [
            AgingBucket(label: "0-30 days", count: b030, value: v030),
            AgingBucket(label: "31-60 days", count: b3160, value: v3160),
            AgingBucket(label: "61-90 days", count: b6190, value: v6190),
            AgingBucket(label: "91-180 days", count: b91180, value: v91180),
            AgingBucket(label: "180+ days", count: b180plus, value: v180plus),
        ]

        let slowMovers = available
            .filter { (calendar.dateComponents([.day], from: $0.createdAt, to: today).day ?? 0) > 90 }
            .map { stone in
                SlowMover(
                    sku: stone.sku,
                    stoneType: stone.stoneType.rawValue.capitalized,
                    caratWeight: stone.caratWeight,
                    costPrice: stone.costPrice,
                    daysInInventory: calendar.dateComponents([.day], from: stone.createdAt, to: today).day ?? 0
                )
            }
            .sorted { $0.daysInInventory > $1.daysInInventory }

        return InventoryTurnoverReport(
            currentCount: currentCount,
            currentValue: currentValue,
            soldCount: soldCount,
            soldValue: soldValue,
            turnoverRate: turnoverRate,
            agingBuckets: buckets,
            slowMovers: slowMovers
        )
    }

    // MARK: - Customer Profitability

    @MainActor
    static func generateCustomerProfitability(
        startDate: Date,
        endDate: Date,
        modelContext: ModelContext
    ) -> CustomerProfitabilityReport {
        let paidStatus = InvoiceStatus.paid
        let descriptor = FetchDescriptor<Invoice>(
            predicate: #Predicate<Invoice> { $0.status == paidStatus }
        )
        let invoices = (try? modelContext.fetch(descriptor)) ?? []
        let filtered = invoices.filter { $0.invoiceDate >= startDate && $0.invoiceDate <= endDate }

        var customerMap: [String: (id: PersistentIdentifier?, revenue: Decimal, cogs: Decimal, count: Int)] = [:]

        for invoice in filtered {
            let name = invoice.customer?.displayName ?? "Unknown"
            let custId = invoice.customer?.persistentModelID
            var entry = customerMap[name, default: (custId, 0, 0, 0)]
            entry.id = custId
            entry.count += 1
            entry.revenue += invoice.grandTotal

            for item in invoice.lineItems where item.status == .sold {
                if item.isLotLineItem, let locked = item.lockedCostPerCarat {
                    entry.cogs += locked * Decimal(item.carats)
                } else {
                    entry.cogs += item.gemstone?.costPrice ?? 0
                }
            }
            customerMap[name] = entry
        }

        let rows = customerMap.map {
            CustomerProfitRow(
                customerName: $0.key,
                customerId: $0.value.id,
                totalRevenue: $0.value.revenue,
                totalCOGS: $0.value.cogs,
                transactionCount: $0.value.count
            )
        }.sorted { $0.profit > $1.profit }

        return CustomerProfitabilityReport(rows: rows)
    }

    // MARK: - Margin Analysis

    @MainActor
    static func generateMarginAnalysis(
        startDate: Date? = nil,
        endDate: Date? = nil,
        modelContext: ModelContext
    ) -> MarginAnalysisReport {
        let paidStatus = InvoiceStatus.paid
        let descriptor = FetchDescriptor<Invoice>(
            predicate: #Predicate<Invoice> { $0.status == paidStatus }
        )
        let allInvoices = (try? modelContext.fetch(descriptor)) ?? []
        let invoices: [Invoice]
        if let startDate, let endDate {
            invoices = allInvoices.filter { $0.invoiceDate >= startDate && $0.invoiceDate <= endDate }
        } else {
            invoices = allInvoices
        }

        // Monthly trend (last 12 months)
        let calendar = Calendar.current
        let now = endDate ?? Date()
        var monthlyData: [(month: String, revenue: Decimal, cogs: Decimal)] = []
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM yyyy"

        for i in (0..<12).reversed() {
            guard let monthStart = calendar.date(byAdding: .month, value: -i, to: calendar.startOfMonth(for: now)),
                  let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else { continue }

            let monthInvoices = invoices.filter { $0.invoiceDate >= monthStart && $0.invoiceDate < monthEnd }
            var rev: Decimal = 0
            var cogs: Decimal = 0
            for inv in monthInvoices {
                rev += inv.grandTotal
                for item in inv.lineItems where item.status == .sold {
                    if item.isLotLineItem, let locked = item.lockedCostPerCarat {
                        cogs += locked * Decimal(item.carats)
                    } else {
                        cogs += item.gemstone?.costPrice ?? 0
                    }
                }
            }
            monthlyData.append((dateFormatter.string(from: monthStart), rev, cogs))
        }

        let monthlyTrend = monthlyData.map { data in
            let margin: Double = data.revenue > 0
                ? NSDecimalNumber(decimal: (data.revenue - data.cogs) / data.revenue * 100).doubleValue
                : 0
            return MonthlyMargin(month: data.month, marginPercent: margin, revenue: data.revenue, cogs: data.cogs)
        }

        // By stone type
        var typeMap: [String: (margins: [Double], count: Int)] = [:]
        for inv in invoices {
            for item in inv.lineItems where item.status == .sold {
                let rev = item.netAmount
                let cogs: Decimal
                if item.isLotLineItem, let locked = item.lockedCostPerCarat {
                    cogs = locked * Decimal(item.carats)
                } else {
                    cogs = item.gemstone?.costPrice ?? 0
                }
                guard rev > 0 else { continue }
                let margin = NSDecimalNumber(decimal: (rev - cogs) / rev * 100).doubleValue
                let type = item.gemstone?.stoneType.rawValue.capitalized ?? item.stoneTypeDisplay
                var entry = typeMap[type, default: ([], 0)]
                entry.margins.append(margin)
                entry.count += 1
                typeMap[type] = entry
            }
        }

        let byStoneType = typeMap.map { key, value in
            let avg = value.margins.isEmpty ? 0 : value.margins.reduce(0, +) / Double(value.margins.count)
            return StoneTypeMargin(stoneType: key, avgMarginPercent: avg, count: value.count)
        }.sorted { $0.avgMarginPercent > $1.avgMarginPercent }

        // Distribution histogram
        var under10 = 0, r10_20 = 0, r20_30 = 0, over30 = 0
        var allMargins: [Double] = []
        for inv in invoices {
            for item in inv.lineItems where item.status == .sold {
                let rev = item.netAmount
                let cogs: Decimal
                if item.isLotLineItem, let locked = item.lockedCostPerCarat {
                    cogs = locked * Decimal(item.carats)
                } else {
                    cogs = item.gemstone?.costPrice ?? 0
                }
                guard rev > 0 else { continue }
                let margin = NSDecimalNumber(decimal: (rev - cogs) / rev * 100).doubleValue
                allMargins.append(margin)
                switch margin {
                case ..<10: under10 += 1
                case 10..<20: r10_20 += 1
                case 20..<30: r20_30 += 1
                default: over30 += 1
                }
            }
        }
        let total = Double(allMargins.count)
        var distribution = [
            MarginBucket(label: "< 10%", count: under10),
            MarginBucket(label: "10-20%", count: r10_20),
            MarginBucket(label: "20-30%", count: r20_30),
            MarginBucket(label: "30%+", count: over30),
        ]
        if total > 0 {
            for i in distribution.indices {
                distribution[i].percent = Double(distribution[i].count) / total * 100
            }
        }

        return MarginAnalysisReport(monthlyTrend: monthlyTrend, byStoneType: byStoneType, distribution: distribution)
    }
}

// MARK: - Calendar Helper

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
}
