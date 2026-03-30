import Foundation
import SwiftData

enum DashboardRoutes {
    static func register(router: APIRouter) {
        // GET /api/dashboard — full KPI snapshot
        router.get("/api/dashboard") { _, container in
            let context = ModelContext(container)

            // Inventory stats
            let stoneDesc = FetchDescriptor<Gemstone>()
            let stones = (try? context.fetch(stoneDesc)) ?? []
            let availableStones = stones.filter { $0.status == .available }
            let inventoryCount = availableStones.count
            let inventoryValue = availableStones.reduce(Decimal.zero) { $0 + $1.sellPrice * Decimal($1.caratWeight) }

            // Revenue (paid invoices)
            let invDesc = FetchDescriptor<Invoice>()
            let invoices = (try? context.fetch(invDesc)) ?? []
            let paidInvoices = invoices.filter { $0.status == .paid }
            let totalRevenue = paidInvoices.reduce(Decimal.zero) { $0 + $1.totalAmount }

            // Open memos
            let memoDesc = FetchDescriptor<Memo>()
            let memos = (try? context.fetch(memoDesc)) ?? []
            let openMemos = memos.filter { $0.status == .onMemo }
            let overdueMemos = openMemos.filter { $0.ageInDays > 30 }

            // Recent activity (last 10 invoices/memos)
            let recentInvoices = invoices.sorted { $0.createdAt > $1.createdAt }.prefix(5)
            let recentMemos = memos.sorted { $0.createdAt > $1.createdAt }.prefix(5)

            return .ok([
                "inventoryCount": inventoryCount,
                "inventoryValue": NSDecimalNumber(decimal: inventoryValue).doubleValue,
                "totalRevenue": NSDecimalNumber(decimal: totalRevenue).doubleValue,
                "paidInvoiceCount": paidInvoices.count,
                "openMemoCount": openMemos.count,
                "openMemoValue": NSDecimalNumber(decimal: openMemos.reduce(Decimal.zero) { $0 + $1.openMemoAmount }).doubleValue,
                "overdueMemoCount": overdueMemos.count,
                "recentInvoices": recentInvoices.map { InvoiceRoutes.invoiceJSON($0) },
                "recentMemos": recentMemos.map { MemoRoutes.memoJSON($0) }
            ] as [String: Any])
        }

        // GET /api/dashboard/aging — inventory aging buckets
        router.get("/api/dashboard/aging") { _, container in
            let context = ModelContext(container)
            let stoneDesc = FetchDescriptor<Gemstone>()
            let stones = (try? context.fetch(stoneDesc)) ?? []
            let available = stones.filter { $0.status == .available }

            let calendar = Calendar.current
            let today = Date()
            var buckets: [[String: Any]] = [
                ["label": "0–30 days", "count": 0, "value": 0.0],
                ["label": "31–60 days", "count": 0, "value": 0.0],
                ["label": "61–90 days", "count": 0, "value": 0.0],
                ["label": "90+ days", "count": 0, "value": 0.0],
            ]

            for stone in available {
                let days = calendar.dateComponents([.day], from: stone.createdAt, to: today).day ?? 0
                let idx: Int
                switch days {
                case 0...30: idx = 0
                case 31...60: idx = 1
                case 61...90: idx = 2
                default: idx = 3
                }
                buckets[idx]["count"] = (buckets[idx]["count"] as? Int ?? 0) + 1
                let value = NSDecimalNumber(decimal: stone.sellPrice * Decimal(stone.caratWeight)).doubleValue
                buckets[idx]["value"] = (buckets[idx]["value"] as? Double ?? 0) + value
            }

            return .ok(["buckets": buckets] as [String: Any])
        }

        // GET /api/dashboard/sales — by stone type + monthly trend
        router.get("/api/dashboard/sales") { _, container in
            let context = ModelContext(container)
            let invDesc = FetchDescriptor<Invoice>()
            let invoices = (try? context.fetch(invDesc)) ?? []
            let paidOrSent = invoices.filter { $0.status == .paid || $0.status == .sent }

            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM"

            var byType: [String: Double] = [:]
            var byMonth: [String: Double] = [:]

            for inv in paidOrSent {
                let monthKey = fmt.string(from: inv.invoiceDate)
                byMonth[monthKey, default: 0] += NSDecimalNumber(decimal: inv.totalAmount).doubleValue

                for item in inv.lineItems {
                    byType[item.stoneTypeDisplay, default: 0] += NSDecimalNumber(decimal: item.amount).doubleValue
                }
            }

            let sortedByType = byType.map { ["stoneType": $0.key, "revenue": $0.value] as [String: Any] }
                .sorted { ($0["revenue"] as? Double ?? 0) > ($1["revenue"] as? Double ?? 0) }

            let sortedByMonth = byMonth.map { ["month": $0.key, "revenue": $0.value] as [String: Any] }
                .sorted { ($0["month"] as? String ?? "") < ($1["month"] as? String ?? "") }

            return .ok([
                "byStoneType": sortedByType,
                "monthlyTrend": sortedByMonth
            ] as [String: Any])
        }
    }
}
