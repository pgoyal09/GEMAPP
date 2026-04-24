import Foundation
import SwiftData
import os

// MARK: - Reporting Assumptions
//
// This file implements in-process report generation over SwiftData entities.
// Several computations rely on business assumptions or proxies rather than
// historical ledger snapshots. Key assumptions are documented inline and
// summarized here. See also: REPORTING-MODEL.md for the canonical reference.
//
// 1. COGS (Cost of Goods Sold):
//    - Lot line items use `lockedCostPerCarat` (exact historical cost, frozen at transaction time).
//    - Single-stone line items use `gemstone.costPrice` (current value — PROXY, not cost-at-sale).
//      If costPrice is edited after sale, COGS will silently change. No historical snapshot exists.
//
// 2. Revenue basis varies by report:
//    - P&L and Margin-by-type use `item.netAmount` (line-level, pre-tax, pre-invoice-discount).
//    - Customer Profitability and Margin monthly trend use `invoice.grandTotal`
//      (post-tax, post-invoice-discount). These are intentionally different bases.
//
// 3. Inventory Turnover denominator is a PROXY:
//    - Uses current inventory value at query time, not average of period start/end.
//    - No historical inventory snapshots are stored.
//
// 4. All reports filter to `status == .paid` invoices and `status == .sold` line items
//    unless otherwise noted. Date filtering uses `invoiceDate` (document date, not payment date).
//
// 5. Customer grouping uses `displayName` string, not stable identifier.
//    Name changes or duplicates will fragment or merge customer data.

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

    private static let logger = Logger(subsystem: "com.qualitydiajewels.QDI-Gemstone-ERP", category: "reports")

    // MARK: - COGS Computation (shared)

    /// Compute COGS for a single sold line item using the two-branch rule:
    /// - Lot items: exact historical cost from `lockedCostPerCarat` (frozen at transaction time).
    /// - Single stones: PROXY using current `gemstone.costPrice` (not cost-at-sale).
    private static func computeItemCOGS(_ item: LineItem) -> Decimal {
        if item.isLotLineItem, let lockedCost = item.lockedCostPerCarat {
            // Exact historical cost — frozen at transaction creation via LotService.
            return lockedCost * Decimal(item.carats)
        } else {
            // PROXY: current costPrice, not cost-at-sale. See file-level assumptions §1.
            return item.gemstone?.costPrice ?? 0
        }
    }

    // MARK: - P&L Report
    //
    // Revenue: line-item `netAmount` (pre-tax, pre-invoice-discount).
    // COGS: lot items use historical `lockedCostPerCarat`; single stones use current `costPrice` (PROXY).
    // Grouped by stone type. Sorted by revenue descending.
    // Only paid invoices with sold line items are included.

    @MainActor
    static func generatePLReport(
        startDate: Date,
        endDate: Date,
        modelContext: ModelContext
    ) -> PLReport {
        logger.info("Generating P&L report for \(startDate.formatted(.dateTime.year().month().day()), privacy: .public) – \(endDate.formatted(.dateTime.year().month().day()), privacy: .public)")
        // SwiftData #Predicate does not support custom enum types as captured constants.
        let descriptor = FetchDescriptor<Invoice>()
        // Assumption: only realized (paid) transactions count as revenue.
        let invoices = ((try? modelContext.fetch(descriptor)) ?? [])
            .filter { $0.status == .paid }
        // Assumption: date filtering uses invoiceDate (document date), not payment date.
        let filtered = invoices.filter { $0.invoiceDate >= startDate && $0.invoiceDate <= endDate }

        var typeMap: [String: (units: Int, revenue: Decimal, cogs: Decimal)] = [:]

        for invoice in filtered {
            for item in invoice.lineItems {
                guard item.status == .sold else { continue }
                // Stone type resolution: prefer live gemstone relationship; fall back to
                // stored stoneTypeDisplay string (covers deleted gemstones or unlinked imports).
                let type = item.gemstone?.stoneType.rawValue.capitalized ?? item.stoneTypeDisplay
                // Revenue uses netAmount: line-level amount after per-line discount,
                // excluding invoice-level discount and tax.
                let revenue = item.netAmount
                let cogs = computeItemCOGS(item)
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

        logger.info("P&L report complete: \(rows.count) stone types, revenue=\(totalRevenue), cogs=\(totalCOGS)")
        return PLReport(revenue: totalRevenue, cogs: totalCOGS, breakdownByType: rows)
    }

    // MARK: - Inventory Turnover
    //
    // Turnover rate: COGS in period / current inventory value (APPROXIMATION).
    // The denominator is a PROXY — it uses inventory value at query time, not the
    // average of period-start and period-end values. No historical inventory snapshots
    // are stored, so a true average cannot be computed.
    // Aging buckets and slow movers are exact from stored `createdAt` dates.
    // Note: `createdAt` reflects when the record was created in the system (or imported),
    // not necessarily when the physical stone was acquired.

    @MainActor
    static func generateInventoryTurnover(
        startDate: Date,
        endDate: Date,
        modelContext: ModelContext
    ) -> InventoryTurnoverReport {
        logger.info("Generating inventory turnover report")
        // SwiftData #Predicate does not support custom enum types as captured constants.
        let allDescriptor = FetchDescriptor<Gemstone>()
        let allGemstones = (try? modelContext.fetch(allDescriptor)) ?? []
        let available = allGemstones.filter { $0.status == .available }
        let currentCount = available.count
        // Current inventory valued at cost (costPrice), not sell price.
        let currentValue = available.reduce(Decimal.zero) { $0 + $1.costPrice }

        let invDescriptor = FetchDescriptor<Invoice>()
        let invoices = ((try? modelContext.fetch(invDescriptor)) ?? [])
            .filter { $0.status == .paid }
        let periodInvoices = invoices.filter { $0.invoiceDate >= startDate && $0.invoiceDate <= endDate }

        var soldCount = 0
        var soldValue: Decimal = 0
        for inv in periodInvoices {
            for item in inv.lineItems where item.status == .sold {
                soldCount += 1
                soldValue += computeItemCOGS(item)
            }
        }

        // APPROXIMATION: Turnover rate = COGS / Average Inventory Value.
        // Uses current inventory value as denominator because no period-start snapshot exists.
        // If inventory changed significantly during the period, this rate will be skewed.
        // Not GAAP-compliant — directionally useful only.
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

        logger.info("Inventory turnover complete: \(currentCount) available, \(soldCount) sold, rate=\(String(format: "%.2f", turnoverRate)), \(slowMovers.count) slow movers")
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
    //
    // Revenue: `invoice.grandTotal` (post-tax, post-invoice-discount) — what the customer paid.
    // This is intentionally different from P&L revenue (which uses line-item netAmount).
    // Consequence: grossProfit here is not directly comparable to P&L grossProfit for the
    // same period when invoices have invoice-level discounts or non-zero tax.
    //
    // COGS: same two-branch rule as P&L (see file-level assumptions §1).
    //
    // Customer grouping: by `displayName` string, not stable identifier.
    // If two customers share a name, their data merges. Name changes fragment history.

    @MainActor
    static func generateCustomerProfitability(
        startDate: Date,
        endDate: Date,
        modelContext: ModelContext
    ) -> CustomerProfitabilityReport {
        logger.info("Generating customer profitability report")
        // SwiftData #Predicate does not support custom enum types as captured constants.
        let descriptor = FetchDescriptor<Invoice>()
        let invoices = ((try? modelContext.fetch(descriptor)) ?? [])
            .filter { $0.status == .paid }
        let filtered = invoices.filter { $0.invoiceDate >= startDate && $0.invoiceDate <= endDate }

        // Grouped by displayName string — see method-level note on grouping limitations.
        var customerMap: [String: (id: PersistentIdentifier?, revenue: Decimal, cogs: Decimal, count: Int)] = [:]

        for invoice in filtered {
            let name = invoice.customer?.displayName ?? "Unknown"
            let custId = invoice.customer?.persistentModelID
            var entry = customerMap[name, default: (custId, 0, 0, 0)]
            entry.id = custId
            entry.count += 1
            // Revenue uses grandTotal (includes invoice-level discount + tax).
            entry.revenue += invoice.grandTotal

            for item in invoice.lineItems where item.status == .sold {
                entry.cogs += computeItemCOGS(item)
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

        logger.info("Customer profitability complete: \(rows.count) customers")
        return CustomerProfitabilityReport(rows: rows)
    }

    // MARK: - Margin Analysis
    //
    // This report contains three sub-analyses with DIFFERENT revenue bases:
    //
    // 1. Monthly trend: revenue from `invoice.grandTotal` (post-tax, post-discount).
    //    Same basis as Customer Profitability. Comparable across those two reports.
    //
    // 2. By stone type: revenue from `item.netAmount` (line-level, pre-tax).
    //    Same basis as P&L. Comparable to P&L margin.
    //
    // 3. Margin distribution histogram: same per-item basis as by-stone-type.
    //
    // The monthly trend and by-stone-type sub-reports within this single report
    // use DIFFERENT revenue bases. This is by design but non-obvious to users.
    //
    // By-stone-type margin is a simple average of per-item margins, not weighted by
    // revenue or volume. A stone type with one high-margin sale will rank higher than
    // a type with many moderate-margin sales.

    @MainActor
    static func generateMarginAnalysis(
        startDate: Date? = nil,
        endDate: Date? = nil,
        modelContext: ModelContext
    ) -> MarginAnalysisReport {
        logger.info("Generating margin analysis report")
        // SwiftData #Predicate does not support custom enum types as captured constants.
        let descriptor = FetchDescriptor<Invoice>()
        let allInvoices = ((try? modelContext.fetch(descriptor)) ?? [])
            .filter { $0.status == .paid }
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
                // Monthly revenue uses grandTotal (post-tax, post-invoice-discount).
                rev += inv.grandTotal
                for item in inv.lineItems where item.status == .sold {
                    cogs += computeItemCOGS(item)
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

        // By stone type AND distribution histogram — single pass over all sold line items.
        // Uses item.netAmount for revenue (same basis as P&L, NOT grandTotal).
        // Margin per item is a simple average, not weighted by revenue or carat volume.
        // Items with zero or negative revenue are excluded from both analyses.
        var typeMap: [String: (margins: [Double], count: Int)] = [:]
        var under10 = 0, r10_20 = 0, r20_30 = 0, over30 = 0
        var allMarginsCount = 0
        for inv in invoices {
            for item in inv.lineItems where item.status == .sold {
                let rev = item.netAmount
                let cogs = computeItemCOGS(item)
                guard rev > 0 else { continue }
                let margin = NSDecimalNumber(decimal: (rev - cogs) / rev * 100).doubleValue

                // Stone type accumulation
                let type = item.gemstone?.stoneType.rawValue.capitalized ?? item.stoneTypeDisplay
                var entry = typeMap[type, default: ([], 0)]
                entry.margins.append(margin)
                entry.count += 1
                typeMap[type] = entry

                // Distribution histogram accumulation
                allMarginsCount += 1
                switch margin {
                case ..<10: under10 += 1
                case 10..<20: r10_20 += 1
                case 20..<30: r20_30 += 1
                default: over30 += 1
                }
            }
        }

        let byStoneType = typeMap.map { key, value in
            let avg = value.margins.isEmpty ? 0 : value.margins.reduce(0, +) / Double(value.margins.count)
            return StoneTypeMargin(stoneType: key, avgMarginPercent: avg, count: value.count)
        }.sorted { $0.avgMarginPercent > $1.avgMarginPercent }

        let total = Double(allMarginsCount)
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

        logger.info("Margin analysis complete: \(monthlyTrend.count) months, \(byStoneType.count) stone types")
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
