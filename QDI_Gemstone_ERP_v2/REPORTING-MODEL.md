# GEMAPP Reporting Model and Assumptions

Canonical reference for every report family in GEMAPP: what data it reads, how it computes, and where it uses proxies instead of historical snapshots. Maintainers should update this document whenever report logic changes.

**Implementation:** `Services/ReportEngine.swift`, `Services/ReportExportService.swift`, `Services/ARService.swift`, `ViewModels/DashboardViewModel.swift`

---

## 1. Global Reporting Rules

These rules apply across all report families unless explicitly overridden.

### 1.1 Invoice eligibility

| Report family | Invoice status filter | Rationale |
|---|---|---|
| P&L, Customer Profitability, Margin Analysis | `.paid` only | Only completed transactions count as realized revenue |
| Inventory Turnover (sold side) | `.paid` only | Same — only realized sales |
| Accounts Receivable | `.sent` or `.draft` with `balanceDue > 0` | Tracks unpaid obligations |
| Dashboard (monthly sales) | `.paid` or `.sent` | Includes outstanding but committed sales |

### 1.2 Line item eligibility

All ReportEngine reports filter line items to `status == .sold`. Open, returned, or void items are excluded from revenue and COGS computations.

### 1.3 Date filtering

Reports use `invoice.invoiceDate` for period boundaries (`>= startDate && <= endDate`). This is the document date, not the payment date. Consequence: a sale invoiced in March but paid in April appears in the March report.

### 1.4 COGS computation (universal)

COGS is computed per line item using a two-branch rule:

```
if item.isLotLineItem && item.lockedCostPerCarat != nil:
    COGS = lockedCostPerCarat * carats          // historical cost, frozen at sale time
else:
    COGS = item.gemstone?.costPrice ?? 0        // current inventory cost
```

| Branch | Accuracy | Notes |
|---|---|---|
| Lot items | **Exact (historical)** | `lockedCostPerCarat` is captured when the stone is added to a memo/invoice via `LotService`. It reflects the weighted-average cost at that moment and does not change afterward. |
| Single stones | **Proxy (current)** | Uses the gemstone's current `costPrice` field. If `costPrice` was edited after the sale, COGS will reflect the new value, not the original. No historical snapshot is stored for single-stone cost. |

**Risk:** Single-stone COGS is only exact if `costPrice` is never modified after sale. In practice this is usually true, but the system does not enforce it.

### 1.5 Revenue computation

- **P&L and Margin Analysis:** Use `item.netAmount` (line-item amount after per-line discount). This excludes invoice-level discount and tax.
- **Customer Profitability:** Uses `invoice.grandTotal` for revenue (includes invoice-level discount and tax). COGS is still computed at line-item level.

**Consequence:** P&L revenue and Customer Profitability revenue will not match for the same period if invoices have invoice-level discounts or non-zero tax. P&L measures margin on goods; Customer Profitability measures margin on invoiced amounts.

---

## 2. Report Families

### 2.1 Profit & Loss (P&L)

**Source:** `ReportEngine.generatePLReport()` (line 113)

**Input data:**
- All `Invoice` records with `status == .paid`
- Filtered to `invoiceDate` within the selected date range
- Line items with `status == .sold`

**Computation:**
```
Per line item:
  revenue  = item.netAmount
  cogs     = (lot path or single-stone path, see §1.4)

Aggregation:
  Grouped by stone type (gemstone.stoneType.rawValue.capitalized)
  Per group: unitsSold, revenue, cogs
  grossProfit = revenue - cogs
  marginPercent = (grossProfit / revenue) * 100
  
Totals:
  totalRevenue = sum of all group revenues
  totalCOGS    = sum of all group COGS
```

**Stone type resolution:** Uses `item.gemstone?.stoneType` when the gemstone relationship exists; falls back to `item.stoneTypeDisplay` (a stored string on the line item) when the gemstone is nil. This fallback covers cases where the gemstone was deleted or the line item was imported without a linked stone.

**Sorting:** Breakdown rows sorted by revenue descending.

**Classification:** Mixed — lot COGS is exact historical; single-stone COGS is proxy-based on current cost.

---

### 2.2 Inventory Turnover

**Source:** `ReportEngine.generateInventoryTurnover()` (line 157)

**Input data:**
- All `Gemstone` records (for current inventory state)
- All `Invoice` records with `status == .paid` (for sold-in-period computation)

**Computation:**

#### Current inventory
```
currentCount = count of gemstones with status == .available
currentValue = sum of costPrice for available gemstones
```

#### Sold in period
```
soldCount  = count of sold line items from paid invoices in date range
soldValue  = sum of COGS per item (lot path or single-stone path, see §1.4)
```

#### Turnover rate
```
avgInventory = currentValue (if > 0, else 1 to avoid division by zero)
turnoverRate = soldValue / avgInventory
```

**PROXY WARNING:** The denominator is **current inventory value at query time**, not the average of beginning-of-period and end-of-period inventory. The system does not store historical inventory snapshots. This means:

- If inventory grew significantly during the period, turnover will be understated.
- If inventory shrank significantly, turnover will be overstated.
- The metric is directionally useful but not GAAP-compliant.

The code documents this explicitly (line 190): `"Using current inventory as proxy (no period-start snapshot available)"`.

#### Aging buckets
```
For each available gemstone:
  daysInInventory = calendar days from gemstone.createdAt to today
  
Buckets: 0-30, 31-60, 61-90, 91-180, 180+
Per bucket: count, sum of costPrice
```

**Note:** Aging is based on `createdAt` (the date the record was created in the system), not the date the stone was acquired. For imported stones, `createdAt` reflects import date.

#### Slow movers
```
Available gemstones with daysInInventory > 90
Sorted by daysInInventory descending
Fields: sku, stoneType, caratWeight, costPrice, daysInInventory
```

**Classification:** Turnover rate is **approximation-based** (current inventory proxy). Aging and slow-mover lists are **exact** from stored data.

---

### 2.3 Customer Profitability

**Source:** `ReportEngine.generateCustomerProfitability()` (line 251)

**Input data:**
- All `Invoice` records with `status == .paid`
- Filtered to `invoiceDate` within the selected date range

**Computation:**
```
Per invoice:
  customer = invoice.customer?.displayName ?? "Unknown"
  revenue  = invoice.grandTotal        // NOTE: uses grandTotal, not line-item sum
  cogs     = sum of per-item COGS (lot path or single-stone path, see §1.4)

Per customer:
  totalRevenue      = sum of invoice grandTotals
  totalCOGS         = sum of item-level COGS
  profit            = totalRevenue - totalCOGS
  marginPercent     = (profit / totalRevenue) * 100
  transactionCount  = count of invoices
  avgOrderValue     = totalRevenue / transactionCount
```

**Revenue/COGS mismatch risk:** Revenue includes invoice-level discount and tax (via `grandTotal`). COGS is computed at line-item level and excludes tax/discount. This is intentional — the report shows margin on what the customer actually paid — but means `grossProfit` here is not comparable to P&L `grossProfit` for the same period.

**Customer identity:** Grouped by `displayName` string. If two customers share a display name, their data will be merged in this report. The `customerId` (PersistentIdentifier) is tracked but grouping is name-based.

**Sorting:** By profit descending.

**Classification:** Mixed — same COGS accuracy as P&L. Revenue is exact from stored invoice totals.

---

### 2.4 Margin Analysis

**Source:** `ReportEngine.generateMarginAnalysis()` (line 298)

**Input data:**
- All `Invoice` records with `status == .paid`
- Optional date range filter (if omitted, uses all paid invoices)

**Sub-reports:**

#### Monthly trend (last 12 months)
```
For each of the last 12 calendar months:
  revenue = sum of invoice.grandTotal for paid invoices in that month
  cogs    = sum of per-item COGS for sold line items in those invoices
  margin  = (revenue - cogs) / revenue * 100
```

**Note:** Monthly revenue uses `invoice.grandTotal` (same as Customer Profitability), but COGS is item-level. Same revenue/COGS basis mismatch as Customer Profitability.

#### By stone type
```
For each sold line item across all filtered invoices:
  revenue = item.netAmount
  cogs    = (lot path or single-stone path)
  margin  = (revenue - cogs) / revenue * 100
  
Per stone type: average of all individual item margins
```

**Note:** This sub-report uses `item.netAmount` for revenue (same as P&L), not `grandTotal`. The by-stone-type breakdown and monthly trend within the same report use **different revenue bases**.

#### Margin distribution histogram
```
Same per-item margin computation as by-stone-type
Buckets: < 10%, 10-20%, 20-30%, 30%+
Per bucket: count, percentage of total items
```

Items with zero or negative revenue (`item.netAmount <= 0`) are excluded.

**Sorting:** By-stone-type sorted by average margin descending.

**Classification:** Mixed — same COGS accuracy as P&L. Revenue basis varies by sub-report.

---

### 2.5 Accounts Receivable (AR)

**Source:** `Services/ARService.swift`

**Input data:**
- All `Invoice` records with `status == .sent` or `status == .draft` and `balanceDue > 0`

**Sub-reports:**

#### Unpaid invoices
```
Filter: (status == .sent || status == .draft) && balanceDue > 0
```

**Note:** Draft invoices are included. A draft with a non-zero balance due appears as outstanding AR. This is a product choice — drafts may represent committed but not-yet-sent obligations.

#### Aging buckets
```
For each unpaid invoice:
  referenceDate = dueDate ?? invoiceDate
  daysOverdue   = calendar days from referenceDate to today
  
Buckets: Current (<=0), 1-30, 31-60, 61-90, 90+
Per bucket: invoice list, sum of balanceDue, count
```

**Fallback:** Invoices without a `dueDate` use `invoiceDate` as the aging reference. This means an invoice without a due date ages from its creation, which may overstate how overdue it is.

#### Outstanding by customer
```
Group unpaid invoices by customer.displayName
Per customer: totalOutstanding (sum of balanceDue), invoice list, overdueCount
Sorted by totalOutstanding descending
```

Same name-based grouping caveat as Customer Profitability.

#### Overdue invoices
```
Unpaid invoices where dueDate < today
Invoices without dueDate are excluded (assumed current)
```

#### Severe overdue count (sidebar badge)
```
Unpaid invoices where daysOverdue > 90 (using dueDate ?? invoiceDate)
```

**Classification:** **Exact** — all AR data is computed directly from stored invoice and payment records. `balanceDue = grandTotal - totalPaid` where `totalPaid` excludes voided payments.

---

### 2.6 Dashboard KPIs

**Source:** `ViewModels/DashboardViewModel.swift`

**Input data:**
- All `Gemstone` records (for inventory metrics)
- All `Memo` records (for memo metrics and recent activity)
- All `Invoice` records (for monthly sales)

**Metrics:**

| KPI | Computation | Basis |
|---|---|---|
| Total Carats in Stock | Sum of `caratWeight` (or `effectiveRemainingCarats` for lots) for `status == .available` | Exact — current state |
| Total Inventory Value | Sum of `sellPrice * effectiveCarats` for `status == .available` | Exact — but uses **sell price**, not cost price. This is market/retail value, not cost basis. |
| Total Value on Memo | Sum of `openMemoAmount` for memos with `status == .onMemo` | Exact — computed from memo line items |
| Monthly Sales | Sum of `totalAmount` for invoices with `status == .paid \|\| .sent` and `invoiceDate >= startOfMonth` | Includes sent (unpaid) invoices. Not equivalent to P&L revenue. |
| Open Memo Count | Count of memos with `status == .onMemo` | Exact |
| Overdue Memo Count | Open memos with `ageInDays > 60` | Exact — hardcoded 60-day threshold |
| Inventory Snapshot | Counts by status: available, onMemo, sold | Exact |

**Oldest open memos:** First 5 memos with `status == .onMemo`, sorted by `createdAt` ascending. Shows referenceNumber, customerName, ageDays, openAmount.

**Recent activity:** Last 8 memos by `createdAt` descending, regardless of status.

**Classification:** All dashboard KPIs are **exact from current state**. No historical computation or period aggregation.

---

## 3. Lot Costing Model

Lot stones use a weighted-average cost model implemented in `Services/LotService.swift`.

### 3.1 Cost tracking

```
When carats are added to a lot (addQuantity):
  newAvgCost = (existingCost * existingCarats + costPerCarat * newCarats) / totalCarats
  Uses Decimal arithmetic with 4-decimal rounding to prevent drift
```

### 3.2 Cost locking at transaction time

When a lot is added to a memo or invoice:
```
lineItem.lockedCostPerCarat = lot.effectiveAverageCost
```

This cost is **frozen at transaction creation** and does not change if:
- More carats are added to the lot later (changing the weighted average)
- The lot's cost is manually edited
- Other portions of the lot are sold at different times

### 3.3 Profit computation on lot transactions

```
profitPerCarat = pricePerCarat - lockedCostPerCarat   (only for .sold transactions)
totalProfit    = profitPerCarat * carats
```

### 3.4 Partial depletion

Lots track `effectiveRemainingCarats`. When a lot is fully depleted (remaining <= 0), its status transitions to `.sold`. This is a point-of-no-return — the lot cannot receive new carats unless restored via void/delete/return.

**Classification:** Lot costing is **exact historical** at the per-transaction level. The weighted-average cost computation is deterministic and auditable via the `LotTransaction` ledger.

---

## 4. Export Formats

Reports are exported via `Services/ReportExportService.swift`.

| Report | CSV | PDF |
|---|---|---|
| P&L | Stone Type, Units, Revenue, COGS, Gross Profit, Margin % | HTML table via PDFService |
| Inventory Turnover | Summary metrics + aging buckets + slow movers table | HTML table via PDFService |
| Customer Profitability | Customer, Revenue, COGS, Profit, Margin, Transactions, Avg Order | Not available |
| Margin Analysis | Monthly trend + by stone type + distribution | Not available |

CSV export uses `NSSavePanel` for file location. PDF export uses `PDFService.renderHTMLToPDF()` (WKWebView-based, `@MainActor`).

---

## 5. Proxy vs Exact Summary

| Metric | Classification | Detail |
|---|---|---|
| P&L revenue | Exact | From stored `netAmount` on sold line items |
| P&L COGS (lots) | Exact (historical) | `lockedCostPerCarat` frozen at sale time |
| P&L COGS (single stones) | **Proxy (current)** | Uses current `gemstone.costPrice`, not cost-at-sale |
| Inventory turnover rate | **Proxy (approximation)** | Current inventory as denominator, not period-average |
| Inventory aging | Exact | Based on stored `createdAt` date |
| Customer profitability revenue | Exact | From stored `invoice.grandTotal` |
| Customer profitability COGS | Mixed | Same lot/single split as P&L |
| Margin analysis (monthly) | Mixed | Revenue from `grandTotal`, COGS from items |
| Margin analysis (by type) | Mixed | Revenue from `netAmount`, COGS from items |
| AR balances | Exact | From stored `balanceDue` (grandTotal - totalPaid) |
| AR aging | Exact | From stored `dueDate` or `invoiceDate` fallback |
| Dashboard inventory value | Exact (current) | Sell price * effective carats, current state only |
| Dashboard monthly sales | Exact (current) | Includes sent (unpaid) invoices |

---

## 6. Known Limitations and Future Considerations

1. **No historical inventory snapshots.** The system cannot reconstruct what inventory looked like at a past date. Turnover rate, beginning/ending inventory, and period-over-period comparisons are limited by this.

2. **Single-stone cost is mutable after sale.** Unlike lots, single stones do not lock `costPrice` at transaction time. If a stone's cost is edited after sale, past report runs and future report runs will disagree.

3. **Revenue basis inconsistency across reports.** P&L uses `netAmount` (pre-tax, pre-invoice-discount). Customer Profitability and Margin monthly trend use `grandTotal` (post-tax, post-invoice-discount). This is intentional but undiscoverable without this document.

4. **Customer grouping by display name.** Customer Profitability and AR reports group by `customer.displayName`, not by stable identifier. Name changes or duplicates will fragment or merge customer records in reports.

5. **No voided invoice impact on reports.** Voided invoices have `status == .void` and are excluded from all report families. Void events are not shown as negative entries — they simply disappear from the data set.

6. **AR includes draft invoices.** Drafts with `balanceDue > 0` appear in AR aging. This may overstate actual receivables if drafts are used as internal notes rather than committed obligations.

7. **Aging reference date fallback.** AR aging uses `dueDate ?? invoiceDate`. Invoices without a due date age from their creation, which may not reflect actual payment terms.

8. **Dashboard inventory value uses sell price.** The dashboard's "Total Inventory Value" is a retail/market estimate, not a cost-basis valuation. This differs from the Inventory Turnover report's `currentValue`, which uses `costPrice`.

---

## Cross-References

- **Architecture overview:** [`ARCHITECTURE.md`](ARCHITECTURE.md) § Reporting workflows
- **Service taxonomy:** [`SERVICES-OVERVIEW.md`](SERVICES-OVERVIEW.md) § Reporting / Export
- **Sync model:** [`SYNC-MODEL.md`](SYNC-MODEL.md)
- **Coding agent guidance:** [`CLAUDE.md`](CLAUDE.md)
