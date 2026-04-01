# QDI Gemstone ERP v2 — Clean Rebuild Specification

> **Goal:** Rebuild all Views and DesignSystem from scratch with a clean, consistent architecture.
> **Preserve unchanged:** Models, Services (especially RFID), Utilities, ViewModels, API layer.
> **Stack:** Swift 6.0, SwiftUI, SwiftData, macOS 15+, ORSSerialPort 2.1.0

---

## 1. What We're Preserving (DO NOT MODIFY)

### RFID System (~2,000 LOC) — CRITICAL
These files are battle-tested and must be copied verbatim:
- `Services/RFID/RFIDManager.swift` (946 lines) — Silion framing, POSIX serial, startup handshake
- `Services/RFID/EPCanonical.swift` — EPC tag ID canonicalization
- `Services/RFID/LabelTemplateService.swift` — ZPL label generation for Zebra ZD611R
- `Services/RFID/RFIDReconciliationService.swift` — Inventory reconciliation logic
- `Services/RFID/RFIDScanService.swift` — Scan session management
- `Services/RFID/RFIDService.swift` — Protocol definition
- `ViewModels/RFIDCoordinator.swift` — RFID state coordination
- `ViewModels/ScannerViewModel.swift` — Scanner UI state
- `ViewModels/ReconcileViewModel.swift` — Reconciliation UI state
- `Models/RFIDTag.swift` — Tag data model
- `Models/Enums/RFIDLifecycleStatus.swift` — Tag lifecycle states

### Models (~1,260 LOC) — Preserve all
- Gemstone, Customer, Memo, Invoice, LineItem, Payment, LotTransaction, HistoryEvent, etc.
- All Enums (GemstoneStatus, MemoStatus, InvoiceStatus, LineItemKind, etc.)

### Services (~6,400 LOC) — Preserve all
- TransactionService, LotService, MemoService, InvoiceService
- PDFService, ReportEngine, CloudBackupService
- RapNet API/Sync services
- DemoDataService, SKUGenerator, HistoryLogger, etc.

### Utilities, ViewModels, API — Preserve all
- ~4,200 LOC of ViewModels, Utilities, API routes

### Total preserved: ~14,000 LOC (of 28,000)
### Total to rebuild: ~14,000 LOC (Views + DesignSystem)

---

## 2. Design System — Clean Slate

### 2.1 Design Tokens

**Colors (dark theme, keep existing palette):**
- Background: `#0A0A0F`
- Card/Panel: `#1C1C1E`
- Elevated: `#2C2C2E`
- Accent/Primary: `#00D4AA` (teal-green)
- Danger: `#FF453A`
- Warning: `#FFD60A`
- Ink: `#FFFFFF`
- InkSubtle: `#8E8E93`
- InkMuted: `#636366`

**Corner Radius — NEARLY STRAIGHT (Priyank directive):**
- Fields/inputs: 3pt (barely perceptible rounding)
- Cards/panels: 4pt
- Modals: 6pt
- Buttons: 3pt
- NO large rounded corners anywhere

**Typography (with font size scaling):**
- Read `@AppStorage("displayFontSize")` — Small(+0), Medium(+2), Large(+4)
- Heading: 20pt base, semibold
- Subheading: 15pt base, medium
- Body: 13pt base, regular
- Caption: 11pt base, regular
- Use SF Pro (system font) exclusively

**Spacing:**
- Compact: 4pt
- Standard: 8pt
- Comfortable: 12pt
- Section: 16pt
- Hero: 24pt

### 2.2 Field Style
- Background: `#1C1C1E` (card background)
- Border: 1pt `#3A3A3C` (subtle)
- Corner radius: 3pt
- Height: 28pt (standard), 24pt (compact in tables)
- Focus ring: 1pt primary color
- NO glass/blur effects on fields — clean solid backgrounds

### 2.3 Table Pattern (ONE reusable pattern for all inventory views)
- Sticky header row with subtle bottom border
- Compact rows (32pt height)
- Alternating row backgrounds (subtle, 2% opacity difference)
- Single-click = select, Double-click = open detail
- Detail panel = overlay from right (400pt wide, shadow, dismiss on background tap)
- Footer = sticky below scroll, shows summary stats

### 2.4 Card Pattern
- Solid background, 1pt border
- 4pt corner radius
- No blur/glass effects — clean solid panels
- Subtle shadow only on floating overlays (detail panel, dropdowns)

---

## 3. Navigation Architecture

### Sidebar (always visible)
Groups with keyboard shortcuts:
- **Sales** (⌘1–3)
  - Dashboard
  - Memos
  - Invoices
- **Customers** (⌘4)
  - Customer List
- **Inventory** (⌘5–9)
  - Diamonds
  - Gemstones
  - Lots
  - Sold
  - Quick Intake
  - Quick Entry
  - Review Queue
- **Scanner** (⌘0)
  - RFID Scanner
  - Memo Return
  - Reconciliation
- **Reports**
  - P&L
  - Margin Analysis
  - Customer Profitability
  - Inventory Turnover
- **Settings** (⌘,)

---

## 4. View Specifications

### 4.1 Dashboard
- Left: KPI cards row (Total Inventory Value, Open Memo Value, Revenue MTD, Items Available)
- Center: Recent Activity list + Quick Actions grid
- Right info panel:
  - Open Memos section (count + total value) — NOT inventory snapshot
  - Recent sales
  - Alerts/reminders

### 4.2 Memo Form (Window — opens separately)
**Header:**
- Memo # (auto-generated, non-editable)
- Status badge (only show AFTER line items exist or memo is >60s old)

**Fields row (horizontal):**
- Customer: Single text field. Selected customer name shows IN the field. Type to search, Tab to autocomplete first match. X button inside field to clear. Editing clears customer and starts new search. Dropdown below on type.
- Date: Single text field (MM/DD/YYYY), manually editable. Calendar icon inside field (trailing) opens DatePicker popover. Calendar selection updates field text.
- Salesperson: Optional (controlled by Settings toggle). Simple text field.

**Line Items:**
- Classic table layout (NOT card view):
  - Columns: SKU | Type | Description | Carats | Rate | Amount
  - Clean table rows with compact height
  - NO status badges on individual line items
  - Context menu on right-click: Remove
- Add buttons above table: Single/Pair | Lot | Brokered | Service (simple buttons, not segmented pills)

**Current Open Memo Value card:** Show when customer is selected, total open memos for that customer (excluding current).

**Totals section:** Subtotal, items count.

**Bottom toolbar:** Delete Memo | Export PDF | Email PDF | Cancel | Save (⌘S)
- Cancel: if dirty → show save/discard alert, else close window
- ESC: same as Cancel (via onKeyPress)
- Discard: NSApp.keyWindow?.close()

### 4.3 Invoice Form
Same patterns as Memo form — consistent field behavior, table layout, ESC/Cancel/Discard.

### 4.4 Memo List & Invoice List
- Classic table view (NOT cards) — one row per memo/invoice
- Columns: Ref# | Customer | Date | Items | Total | Status
- Single-click select, double-click opens in new window
- Summary footer: count, total value
- Search + filter chips

### 4.5 Diamonds / Gemstones Inventory
- Reusable table component
- Search bar + filter chips (shape, status, color, clarity, price range)
- Table with columns appropriate to stone type
- Single-click select (highlight row)
- Double-click opens detail panel as OVERLAY (from right, 400pt, dimmed background behind)
- Detail panel: 2-column grid layout for key-value pairs (wider, no scrolling needed)
  - Sections: Identity, Measurements, Characteristics, Certification, Pricing, RFID, History
- Multi-select toolbar (bulk edit, export)
- Sticky summary footer

### 4.6 Lots Inventory
- Table view with: Lot # | Stone Type | Carats | Stones | Avg Cost/ct | Sell Price | Status
- Double-click opens detail showing: Stone Type, Dimensions, Quality, Price/ct, Transaction History
- Average cost = per CARAT (not per stone)
- Add Quantity, Add to Memo, Add to Invoice actions

### 4.7 Sold Inventory
- Table: SKU | Stone Type | Carats | Cost | Sold Price | Margin | Customer | Date
- Vertical scroll only, sticky footer

### 4.8 Quick Intake (Simplified)
- Start with essential fields only: Stone Type, Shape, Carat, Color, Clarity, Cost, Sell Price
- "Show Advanced" toggle reveals: dimensions, certification, RFID, cut grade, fluorescence, etc.
- All deterministic fields (shape, color, clarity, cut) have dropdown with autocomplete

### 4.9 Quick Entry (Table-based)
- Spreadsheet-style entry: each row is a stone
- Column headers aligned with data fields (no drifting)
- Row type selector: Single | Pair | Lot
- Tab between fields, Enter to add row

### 4.10 Customer List
- Table: Name | Company | Email | Phone | Open Memos | Total Purchases
- Double-click opens nested detail view:
  - Customer info bar at top
  - Tabs: Memos | Invoices | Sold Items
  - Each tab shows line items with full detail

### 4.11 Scanner / RFID Views
- Preserve ALL existing RFID view logic and layout patterns
- ScannerView, MemoReturnScanView, UnknownTagAssignSheet, ReconcileView
- These wire directly to the preserved RFID services — only update to use new DesignSystem tokens

### 4.12 Stone Detail Panel (Overlay)
- Width: 400pt
- 2-column LazyVGrid for key-value pairs
- Sections with dividers: Identity, Measurements, Characteristics, Certification, Pricing, RFID, History
- Edit button opens form sheet
- Close button (X) in top-right + tap dimmed background to dismiss

### 4.13 Reports
- Preserve existing ReportEngine logic
- P&L default to All Time (not This Month)
- Clean chart rendering with proper axis labels

### 4.14 Settings
- Company info, Salesperson toggle, Font Size (Small/Medium/Large)
- RFID/Label settings
- RapNet settings
- Cloud Backup settings
- Help Center (⌘?)

---

## 5. Supabase Integration

### 5.1 Setup Requirements
1. Create Supabase project at supabase.com
2. Add `supabase-swift` SPM dependency
3. Store URL + anon key in Keychain (not hardcoded)

### 5.2 Database Schema (mirrors SwiftData models)
Tables needed:
- `gemstones` — all stone data
- `customers` — customer records
- `memos` — memo headers
- `invoices` — invoice headers
- `line_items` — shared line items for memos/invoices
- `lot_transactions` — lot history
- `payments` — payment records
- `history_events` — audit trail
- `rfid_tags` — tag assignments

### 5.3 Sync Strategy
- SwiftData remains local source of truth (offline-first)
- Supabase syncs on save (background, non-blocking)
- Conflict resolution: last-write-wins with timestamp
- RLS policies: user_id based (single-tenant for now)

### 5.4 Auth
- Email/password auth
- Session persisted in Keychain
- Auto-sign-in on app launch

---

## 6. Build Order (Phases)

### Phase 1: DesignSystem + Shell
- AppColors, AppSpacing, AppTypography (with font scaling)
- Field styles, button styles, table components
- Sidebar + navigation shell
- Empty placeholder views for all screens

### Phase 2: Core Views
- Dashboard (KPIs + Open Memos panel)
- Diamonds/Gemstones tables with overlay detail panel
- Lots table with correct avg cost/ct formula
- Sold table
- Customer list + detail drill-down

### Phase 3: Transaction Forms
- Memo form (window-based) with all field behaviors
- Invoice form (matching patterns)
- Memo/Invoice list views (table style)
- Line item table within forms

### Phase 4: Intake + Entry
- Quick Intake (simplified + advanced toggle)
- Quick Entry (spreadsheet-style)
- Review Queue

### Phase 5: Scanner + RFID
- Wire preserved RFID services to new DesignSystem
- Scanner, Memo Return, Reconciliation views

### Phase 6: Reports + Settings
- All report views with ReportEngine
- Settings views
- Help Center

### Phase 7: Supabase
- SPM dependency + client init
- Auth flow (login screen)
- Background sync service
- RLS policies

---

## 7. Critical Constraints

1. **RFID code is UNTOUCHABLE** — copy verbatim, only update DesignSystem token references
2. **SwiftData #Predicate cannot filter enums** — all enum filtering must be fetch-all + in-memory filter
3. **Seed timing must remain in ModelContainer init** (not view onAppear)
4. **Corner radius: 3-4pt maximum** — nearly straight edges per Priyank directive
5. **No glass/blur effects** — clean solid backgrounds
6. **Detail panels are overlays**, not sidebars that push content
7. **ESC always works** — use onKeyPress(.escape), not onExitCommand
8. **Window close = NSApp.keyWindow?.close()** — dismiss() doesn't work on WindowGroup
9. **Font size setting must actually work** — AppTypography reads UserDefaults
10. **Memo pill only shows after line items exist** — not on customer assignment
