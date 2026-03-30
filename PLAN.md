# UI Refactor Plan — Figma Dark Glass Theme

> **Source**: [Figma Site](https://khaki-trek-75668144.figma.site) + Figma Make source (`Fd60bCCkfoGGJZgbadI0Us`)
> **Target**: Native macOS SwiftUI app (`QDI_Gemstone_ERP`)
> **Rule**: Preserve 100% of existing business logic, state management, and data flows.
> **Status**: AWAITING "PROCEED" — No view files will be modified until approved.

---

## 1. Design Summary

The Figma design moves from the current **light dusty-teal** aesthetic to a **dark glass-morphism** theme:

| Aspect | Current App | Figma Design |
|---|---|---|
| Background | Light green `#EDF2ED` | Dark navy gradient `#0a1628 → #0d2137` |
| Cards | Solid light cards with stroke | Glass cards: `white/5%` fill + `white/8%` border + backdrop blur |
| Primary accent | Dusty teal `#8FB0A8` | Cyan `#38bdf8` |
| Text | Dark ink on light | Light text on dark (`white/90%` → `white/25%` hierarchy) |
| Sidebar | Light panel bg | Dark glass panel `white/4%` with glowing active states |
| Selection highlight | Teal opacity | Cyan `#38bdf8` at 8% opacity |
| Typography | Rounded system font | Inter / system sans-serif |
| Status badges | Capsule pills | Rounded rectangles with color fills (`emerald`, `rose`, `amber`, `cyan`, `violet`) |
| Shadows | Outer shadow on cards | Minimal; glow effects (`shadow-cyan-500/20`) |

---

## 2. Semantic Color Map (theme.css → DesignTokens.swift)

```
Figma CSS Variable           → SwiftUI AppColors equivalent
─────────────────────────────────────────────────────────────
--background: #0b1a2e        → background
--foreground: #e2eaf4        → ink
--card: rgba(255,255,255,0.06) → cardBackground
--border: rgba(255,255,255,0.1) → cardStroke
--primary: #38bdf8           → primary
--accent: rgba(56,189,248,0.15) → accent (highlight)
--destructive: #f43f5e       → danger
--muted-foreground: #7da4c7  → inkMuted
Emerald: #34d399             → success
Rose: #f472b6 / #f43f5e     → danger / destructive
Amber: #fbbf24               → warning
Violet: #a78bfa              → accentPurple (new)
Cyan-to-blue gradient        → primaryGradient (new)
```

---

## 3. File-by-File Change Specification

### Phase 0: Design Tokens (1 file — zero risk)

**File: `QDI_Gemstone_ERP/Utilities/DesignTokens.swift`**

| Token | Old Value | New Value |
|---|---|---|
| `background` | `(0.93, 0.95, 0.93)` light green | `(0.04, 0.10, 0.18)` dark navy `#0b1a2e` |
| `panelBackground` | `(0.89, 0.92, 0.90)` | `Color.white.opacity(0.04)` |
| `cardBackground` | `(0.95, 0.96, 0.94)` | `Color.white.opacity(0.05)` |
| `cardElevated` | `(0.97, 0.98, 0.96)` | `Color.white.opacity(0.06)` |
| `primary` | `(0.56, 0.69, 0.66)` teal | `(0.22, 0.74, 0.97)` cyan `#38bdf8` |
| `accent` | `(0.86, 0.70, 0.53)` sand | `Color(0.22, 0.74, 0.97).opacity(0.15)` |
| `success` | `(0.47, 0.67, 0.57)` | `(0.20, 0.83, 0.60)` emerald `#34d399` |
| `warning` | `(0.83, 0.67, 0.47)` | `(0.98, 0.75, 0.14)` amber `#fbbf24` |
| `danger` | `(0.72, 0.50, 0.49)` | `(0.96, 0.25, 0.37)` rose `#f43f5e` |
| `ink` | `(0.22, 0.26, 0.25)` dark | `Color.white.opacity(0.90)` |
| `inkMuted` | `(0.38, 0.44, 0.42)` | `Color.white.opacity(0.50)` |
| `inkSubtle` | `(0.52, 0.57, 0.55)` | `Color.white.opacity(0.30)` |
| `cardStroke` | `(0.72, 0.78, 0.75).opacity(0.35)` | `Color.white.opacity(0.08)` |
| `softHighlight` | `Color.white.opacity(0.75)` | `Color.white.opacity(0.04)` |
| `softShadow` | `(0.56, 0.62, 0.60).opacity(0.22)` | `Color(0.22, 0.74, 0.97).opacity(0.20)` |
| `shellGradient` | light teal gradient | dark navy gradient `#0a1628 → #0d2137 → #0f1f33` |

**New tokens to add:**
- `accentPurple` = `Color(0.65, 0.55, 0.98)` — `#a78bfa`
- `accentRose` = `Color(0.96, 0.45, 0.71)` — `#f472b6`
- `primaryGradient` = `LinearGradient(colors: [cyan, blue], ...)` — for primary buttons
- Stone type colors: `diamondColor`, `rubyColor`, `sapphireColor`, `emeraldColor`, `tanzaniteColor`
- `glassBackground` = `Color.white.opacity(0.05)` — for glass card material
- `glassBorder` = `Color.white.opacity(0.08)` — for glass card border

**Preserved (no change):**
- `AppSpacing.*` — spacing values are compatible
- `AppCornerRadius.*` — Figma uses similar radii (xl = rounded-2xl ≈ 16pt)
- `AppTypography.*` — update font design from `.rounded` to `.default` (Inter-like)
- `InspectorWidth.*` — no change needed
- `Notification.Name` extensions — untouched

### Phase 1: Reusable Components (1 file)

**File: `QDI_Gemstone_ERP/Utilities/DesignTokens.swift`** (same file, component section)

Update `AppSurfaceCard`:
- Change fill from solid `cardBackground` to `glassBackground`
- Change stroke from `cardStroke` to `glassBorder`
- Add `.background(.ultraThinMaterial)` for native glass blur on dark backgrounds

Update `AppStatusBadge`:
- Use new status color palette (emerald/rose/amber/cyan/violet)
- Change shape from `Capsule` to `RoundedRectangle(cornerRadius: 6)`

Update `AppSearchFieldStyle`:
- Dark input: `glassBackground` fill + `glassBorder` stroke
- White text placeholder at 20% opacity

New component `GlassCard`:
- Simple rounded rect with `white/5%` fill + `white/8%` border
- Matches the Figma `GlassCard` pattern used everywhere

New component `GradientButton`:
- Cyan-to-blue gradient background for primary CTA buttons
- Matches `bg-gradient-to-r from-cyan-500 to-blue-500` in Figma

New component `StoneTypeBadge`:
- Colored pill per stone type (Diamond=cyan, Ruby=rose, Sapphire=indigo, Emerald=emerald, Tanzanite=violet)
- Matches `typeColors` in Figma source

---

### Phase 2: Shell & Sidebar (2 files)

**File: `QDI_Gemstone_ERP/Views/SidebarView.swift`**
- State preserved: `@Binding var selectedItem: NavigationItem` — NO CHANGE
- Layout changes:
  - Background: dark glass panel (`white/4%` + border `white/8%`)
  - Logo section: diamond icon in cyan-blue gradient circle
  - Section labels: uppercase tracking, `white/30%` text
  - Nav rows: glass active state (`white/10%` + border), inactive `white/50%`
  - Bottom: Settings button (placeholder)
  - Remove current `AppSurfaceCard` header

**File: `QDI_Gemstone_ERP/Views/AppShellView.swift`**
- State preserved: ALL `@State` vars, `routeBinding`, keyboard shortcuts — NO CHANGE
- Layout changes:
  - Top header bar: page title + notification bell + avatar circle
  - Main content area wrapped in glass container (rounded-2xl with white/4% bg)
  - Background: dark navy gradient (from `shellGradient`)
  - Alert styling: dark popover backgrounds

---

### Phase 3: Dashboard (1 file)

**File: `QDI_Gemstone_ERP/Views/DashboardView.swift`**

**State preserved (DO NOT TOUCH):**
- `@State private var viewModel`, `showAddStoneSheet`, `selectedMemoID`, `selectedPanelItem`, `showResetConfirm`, `resetSuccessMessage`, `isResetting`
- `performReset()` function
- `viewModel.load(modelContext:)` calls
- All `.onAppear`, `.onChange`, `.onReceive` handlers
- All `openWindow` calls

**Layout changes:**
1. **Summary stats row** (`summaryWidgetsRow`):
   - 4-column grid of glass cards
   - Each card: label (uppercase tiny), large value, trend indicator with arrow icon
   - **REQUIRES LOGIC ADDITION**: `DashboardViewModel` needs trend % fields (see Phase 7)
   - Fallback: show cards without trend until Phase 7

2. **Charts row** (NEW — 2:1 grid):
   - Left 2/3: "Revenue & Profit" area chart — **REQUIRES LOGIC ADDITION** for monthly revenue data
   - Right 1/3: "Inventory Mix" donut chart — can derive from `allGemstones` grouped by `stoneType`
   - SwiftUI Charts framework (`import Charts`) for native implementation

3. **Quick Actions** (`functionCardGrid`):
   - 4x2 grid of compact icon buttons (gradient icon circle + label)
   - Replace tall `DashboardActionCard` with compact `QuickActionButton`
   - Same actions/callbacks preserved

4. **Recent Activity** (`recentActivitySection`):
   - Glass card with activity rows
   - Add relative timestamps ("2m ago", "1h ago") — use `RelativeTimeFormatter`
   - Each row: text + time label, separated by thin `white/4%` dividers

5. **Remove right info panel** — Figma design has no right panel; replace with additional dashboard content
   - RFID status can move to header or a collapsible section
   - Oldest open memos section can move below recent activity
   - "Generate New Mock Data" button moves to a settings area or bottom of dashboard

---

### Phase 4: Inventory Views (2 files)

**File: `QDI_Gemstone_ERP/Views/InventoryListView.swift`**

**State preserved (DO NOT TOUCH):**
- `@Binding var selectedNavigationItem`, `mode`, `@Query`, `@State private var viewModel`, `selectedStoneID`, `showEditSheet`, `showColorColumn`
- `baseGemstones`, `filteredGemstones`, `selectedStone` computed properties
- All keyboard shortcuts and `.sheet` modifiers
- `InventoryViewModel` filtering logic

**Layout changes:**
1. Search bar: dark glass input with magnifying glass icon
2. Stone type filter: horizontal pill buttons (All/Diamond/Ruby/etc.) with cyan active state
3. Summary strip: inline stats "Available X | On Memo X | N shown"
4. Table: glass card container, sticky header with uppercase tracking labels
5. Table rows: hover `white/3%`, selected `cyan/8%`, stone type colored badges
6. Detail panel (right): glass cards for Overview/Characteristics/Pricing sections
   - SKU header card with status + type badges
   - Key-value rows inside glass sub-cards

**File: `QDI_Gemstone_ERP/Views/LotInventoryView.swift`**
- Same glass treatment as above
- Already has pill buttons; update colors to dark theme

---

### Phase 5: Memos & Invoices (4 files)

**File: `QDI_Gemstone_ERP/Views/MemosView.swift`** (list + MemoDocumentView)

**State preserved (DO NOT TOUCH):**
- ALL `@State`, `@Query`, `@Binding` vars in `MemosListView` and `MemoDocumentView`
- Tab switching logic (`selectedTab: MemosTab`)
- `performSave()`, `saveAndClose()`, `closeWindow()`
- All sheet presentations and alert modifiers
- All `TransactionViewModel` method calls

**Layout changes:**
1. Open/Closed tab switcher: rounded-xl segmented buttons (cyan active)
2. "New Memo" button: gradient cyan-blue button
3. Memo list table: glass card, uppercase headers, hover/select states
4. Days old column: color-coded (emerald < amber < rose)
5. **MemoDocumentView detail panel**: glass cards for header, line items, total
6. Pill add-line buttons already exist — update colors to dark theme

**File: `QDI_Gemstone_ERP/Views/InvoiceListView.swift`**
- Tab switcher: All / Outstanding / Paid pills
- Table: glass card treatment
- Status badges: Paid=emerald, Outstanding=amber, Overdue=rose

**File: `QDI_Gemstone_ERP/Views/InvoiceDetailView.swift`**
- Same glass treatment as MemoDocumentView
- Pill add-line buttons update to dark theme

**File: `QDI_Gemstone_ERP/Views/EditableLineItemRow.swift`**
- Update colors for dark background: text white/80%, muted white/40%

---

### Phase 6: Other Screens (6 files)

**File: `QDI_Gemstone_ERP/Views/CustomerListView.swift`**
- Search bar + "Add Customer" gradient button
- Glass card table with contact info (email + phone icons)
- Status badge: Active=emerald, Inactive=gray

**File: `QDI_Gemstone_ERP/Views/AccountingView.swift`**
- Stats cards: icon in gradient circle + value + label
- Overview/Transactions tab pills
- Revenue & Profit area chart (Charts framework)
- Monthly Profit bar chart
- Transactions table: income=emerald, expense=rose

**File: `QDI_Gemstone_ERP/Views/ScannerView.swift`**
- Connection status glass card with gradient icon
- Connect/Disconnect button styling
- Stats grid: Tags Read / Matched / Mismatched
- Results table: matched=emerald, mismatched=rose

**File: `QDI_Gemstone_ERP/Views/QuickIntakeView.swift`**
- "Add Row" outline button + "Save All" gradient button
- Glass table with dark input fields
- Delete button: rose on hover

**File: `QDI_Gemstone_ERP/Views/ReviewQueueView.swift`**
- Left sidebar list: dark glass, cyan-selected row
- Two-column form: Core Identity + Detail/Commercial glass cards
- "Save & Next" gradient violet button, "Save" outline button
- Certificate & Media: dashed-border upload areas

**File: `QDI_Gemstone_ERP/Views/InventoryReconcileView.swift`**
- Summary cards: Matched(emerald), Misplaced(amber), Missing(rose)
- "Run Reconcile" gradient button
- Table with status icons and color-coded text

---

### Phase 7: Logic Additions (REQUIRES PERMISSION)

These are the ONLY changes that touch business logic/ViewModels:

1. **`DashboardViewModel`**: Add trend/delta computed properties
   - `caratsTrend: String` — percentage change in total carats (compare to 30 days ago)
   - `memoValueTrend: String` — percentage change in value on memo
   - **Approach**: Use `HistoryEvent` timestamps or store daily snapshots
   - **If rejected**: Dashboard KPI cards show values only, no trend arrows

2. **`DashboardViewModel`**: Add monthly revenue/profit data
   - `monthlyRevenue: [(month: String, revenue: Decimal, profit: Decimal)]`
   - Derived from paid `Invoice` data grouped by month
   - **If rejected**: Revenue chart section omitted from dashboard

3. **Relative time formatting** (utility, not logic):
   - Simple `Date` extension: `func relativeTimeString() -> String`
   - Pure formatting, no data model changes

---

## 4. Execution Queue

| Step | Files | Risk | Description |
|------|-------|------|-------------|
| **0** | `DesignTokens.swift` | Zero | Update color palette, add new tokens, update card/badge components |
| **1** | `SidebarView.swift` | Low | Dark glass sidebar layout |
| **2** | `AppShellView.swift` | Low | Dark shell + top header bar |
| **3a** | `DashboardView.swift` | Medium | Dashboard layout (skip trends/charts initially) |
| **3b** | `DashboardView.swift` | Medium | Add charts using Charts framework |
| **4a** | `InventoryListView.swift` | Medium | Glass table + filter pills + detail panel |
| **4b** | `LotInventoryView.swift` | Low | Dark theme update |
| **5a** | `MemosView.swift` | Medium | List + document view dark theme |
| **5b** | `InvoiceListView.swift` | Low | Invoice list dark theme |
| **5c** | `InvoiceDetailView.swift` | Medium | Invoice detail dark theme |
| **5d** | `EditableLineItemRow.swift` | Low | Row colors update |
| **6a** | `CustomerListView.swift` | Low | Customer list dark theme |
| **6b** | `AccountingView.swift` | Medium | Accounting with charts |
| **6c** | `ScannerView.swift` | Low | Scanner dark theme |
| **6d** | `QuickIntakeView.swift` | Medium | Quick intake dark theme |
| **6e** | `ReviewQueueView.swift` | Medium | Review queue dark theme |
| **6f** | `InventoryReconcileView.swift` | Low | Reconcile dark theme |
| **7** | `DashboardViewModel.swift` | High | Trend data + monthly revenue (NEEDS PERMISSION) |

---

## 5. Preserved State Inventory

The following state/logic MUST NOT be modified during the refactor:

### Models (NEVER TOUCH)
- `Gemstone.swift`, `LineItem.swift`, `Memo.swift`, `Invoice.swift`, `Customer.swift`, `HistoryEvent.swift`, `LotTransaction.swift`, `RFIDTag`

### ViewModels (NEVER TOUCH except Phase 7 additions)
- `DashboardViewModel`, `InventoryViewModel`, `MemosViewModel`, `InvoicesViewModel`, `CustomersViewModel`, `TransactionViewModel`, `ScannerViewModel`, `ReconcileViewModel`

### Services (NEVER TOUCH)
- `DemoDataManager`, `RFIDService`, `RFIDManager`, `RFIDCoordinator`, `RFIDScanService`, `PDFService`, `SKUGenerator`, `DataSeeder`

### App Entry (NEVER TOUCH)
- `QDI_Gemstone_ERPApp.swift` — schema, model container, window groups

### State Bindings Per View
Every `@State`, `@Binding`, `@Query`, `@Environment`, `@EnvironmentObject` declaration in each view file is preserved verbatim. Only the `body` computed property and private layout helpers change.

---

## 6. Validation Checklist

After each step:
- [ ] `xcodebuild` succeeds with zero errors
- [ ] All `@State`/`@Binding` vars unchanged
- [ ] All `.sheet`, `.alert`, `.onAppear`, `.onChange` modifiers preserved
- [ ] All `openWindow`, `TransactionViewModel`, `modelContext` calls preserved
- [ ] Keyboard shortcuts still work
- [ ] Window close behavior unchanged
- [ ] RFID scanning unaffected
- [ ] Mock data generation works

---

## 7. Figma Source Reference

All Figma source files are downloaded to `figma-source/` for reference:
- `DashboardLayout.tsx` — Shell + sidebar structure
- `Overview.tsx` — Dashboard page (KPI cards, charts, quick actions, activity)
- `CurrentInventory.tsx` — Inventory list + detail panel
- `SoldInventory.tsx` — Sold inventory list + detail
- `Memos.tsx` — Memo list + detail panel
- `Invoices.tsx` — Invoice list
- `Customers.tsx` — Customer list
- `Accounting.tsx` — Accounting stats + charts + transactions
- `Scanner.tsx` — Scanner status + results
- `QuickIntake.tsx` — Quick intake table form
- `ReviewQueue.tsx` — Review queue sidebar + edit form
- `Reconcile.tsx` — Reconciliation summary + table
- `theme.css` — Full color variable definitions

---

**AWAITING "PROCEED" TO BEGIN IMPLEMENTATION.**
