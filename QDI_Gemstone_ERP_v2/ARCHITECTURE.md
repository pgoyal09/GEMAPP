# QDI Gemstone ERP v2 — Architecture Overview

Canonical technical reference for the actual system as built. See `CLAUDE.md` for coding-agent guidance and pitfall notes.

---

## 1. What This App Is

QDI Gemstone ERP v2 is a **native macOS desktop ERP / system-of-record** for Quality Diajewels Inc. It is not merely an inventory browser — it is a specialized vertical B2B operating tool covering:

- Gemstone inventory management (diamonds, colored gemstones, lots)
- Customer relationship management
- Memo and invoice document workflows
- Payment tracking and accounts receivable
- Lot-level partial-carat allocation and costing
- RFID hardware-assisted scan, assign, and reconcile flows
- Business reporting (P&L, turnover, profitability, margin analysis)
- Backup, restore, and cloud sync (Supabase)
- RapNet integration for diamond listing/sync
- Desktop multi-window document operation with keyboard-driven workflows

---

## 2. Subsystem Map

| Subsystem | Owner Files / Folders | Primary Abstractions | Key Risks |
|---|---|---|---|
| **Inventory** | `Views/Inventory/`, `ViewModels/InventoryViewModel`, `ViewModels/LotInventoryViewModel` | Gemstone, LotTransaction, InventoryFilterBar | Heavy view-local state; filter/sort duplication across diamond/gem/lot/sold variants |
| **Transactions** | `Views/Transactions/`, `ViewModels/MemoListViewModel`, `ViewModels/InvoiceListViewModel`, `ViewModels/TransactionEditorViewModel` | Memo, Invoice, LineItem, Payment | Multi-window document coordination; unsaved-change guarding |
| **Customers / AR** | `Views/Customers/`, `Views/Accounting/`, `ViewModels/CustomerListViewModel`, `ViewModels/AccountingViewModel` | Customer, PaymentReminder, ARService | AR aging depends on memo/invoice payment state accuracy |
| **RFID / Scanner** | `Services/RFID/`, `ViewModels/ScannerViewModel`, `ViewModels/ReconcileViewModel`, `ViewModels/RFIDCoordinator`, `Views/Scanner/` | RFIDManager, RFIDService protocol, RFIDScanService, RFIDReconciliationService | Hardware state machine complexity; threading discipline required |
| **Reporting** | `Views/Reports/`, `Services/ReportEngine`, `Services/ReportExportService` | ReportEngine, PLReportView, MarginAnalysisView | Some metrics use proxies rather than historical ledger snapshots |
| **Backup / Restore** | `Services/BackupService`, `Services/BackupScheduler`, `Services/CloudBackupService` | BackupManifest, BackupService | Store sidecar file handling; restore rollback safety |
| **Sync / Auth** | `Services/Supabase/` | SupabaseManager, SupabaseSyncService, SupabaseAuthService, SyncDTO, SyncTracker | Last-write-wins conflict model; business-key identity matching |
| **RapNet** | `Services/RapNet/`, `Services/RapNetExportService` | RapNetAPIService, RapNetSyncService | External API dependency; field mapping correctness |
| **Shell / Navigation** | `Views/Shell/`, `App/` | AppShellView, SidebarView, NavigationItem, NavigationGuard | Menu/command routing via notifications; onboarding gate logic |
| **Design System** | `DesignSystem/` | AppColors, AppTypography, AppSpacing, GlassCard, FilterPill, StatusBadge | Consistency depends on all views using shared components |
| **PDF / Export** | `Services/PDFService`, `Services/BatchPDFExporter`, `Services/ShareService`, `Services/CSVImportService` | PDFService (WKWebView-based), CSVImportService | PDF is @MainActor; large exports should not block UI |
| **API Server** | `API/` | Embedded local API server | Started from shell on app launch |

---

## 3. Claimed Architecture vs Actual Architecture

### What CLAUDE.md claims

- MVVM + stateless service layer
- Services are stateless `enum` types with `static` methods
- SwiftData local persistence, no server
- 8 model types in the container

### What the code actually is

**What matches:**
- There is a real ViewModel layer (`@Observable`, `@MainActor`)
- There is a real service layer with business logic separated from views
- SwiftData is the primary local persistence mechanism
- A design system centralizes styling and shared components
- Business logic is often delegated to services from ViewModels

**Where reality diverges:**

1. **Services are not all stateless enums.** The service layer includes:
   - Stateless enum services: TransactionService, MemoService, InvoiceService, LotService, ARService, BackupService, SKUGenerator, etc.
   - Observable class services: CloudBackupService, PDFService, RapNetSyncService, SupabaseSyncService, SupabaseAuthService
   - Manager objects: SupabaseManager, RFIDManager
   - Schedulers: BackupScheduler
   - Protocols: RFIDService, MemoServiceProtocol, InvoiceServiceProtocol, TransactionServiceProtocol, LabelPrintServiceProtocol

2. **The app is not purely local.** It has meaningful Supabase cloud sync and auth, RapNet API integration, cloud backup, and an embedded API server. "Local persistence, no server" understates the actual scope.

3. **More than 8 model types.** The container includes at minimum: Gemstone, Customer, Memo, Invoice, LineItem, RFIDTag, LotTransaction, HistoryEvent, Payment, PaymentReminder, BackupManifest, ReconciliationRecord.

4. **MVVM adherence varies by module.** Transaction/memo/invoice screens use dedicated ViewModels. Inventory screens (diamonds, gemstones, lots, sold) retain substantial filter/sort/search/import/export state directly in views.

5. **Shell view hosts non-trivial logic.** Overdue memo fetching, notification computation, and some coordination happen directly in AppShellView.

### Best working description

> SwiftUI + SwiftData desktop ERP with mixed MVVM/service architecture, several mature infrastructure subsystems, and some feature modules that still carry heavy view-local state.

---

## 4. Runtime / Bootstrap Model

**Entry point:** `App/QDIGemstoneERPApp.swift`

- macOS-only SwiftUI `@main` App lifecycle with `NSApplicationDelegateAdaptor`
- Custom quit flow guards unsaved document windows before termination (notification + polling for up to 3 seconds)

**Startup sequence (from `onAppear` of main shell):**
1. Shared SwiftData `ModelContainer` initialized with `GemAppMigrationPlan`
2. Custom store path: `QDIGemstoneERP_v2.store` (avoids v1 collision)
3. On migration failure: in-memory fallback container with UI-blocked alert and export/reset options
4. Phase 2 migrations run
5. Demo data seeded in DEBUG when `seedDemoData` user default is enabled
6. RFID manager and coordinator setup
7. API server started
8. Backup scheduler configured
9. Appearance set from `@AppStorage("appAppearance")`, defaulting to dark

**Onboarding gate:** App requires both `onboardingComplete` flag and non-empty `companyName`.

**Window model:**
- Three WindowGroups: main app, memo document, invoice document
- Document windows open via `openWindow(value: PersistentIdentifier)`
- Each document window gets its own `DocumentDirtyTracker`
- `NavigationGuard` prevents sidebar navigation with unsaved changes
- Menu command routing uses notifications, not a centralized command bus

**Keyboard:** Extensive shortcut support (Cmd+1..0 for route switching, standard editing commands, custom actions).

---

## 5. Model / Service / ViewModel / View Structure

### Models (SwiftData `@Model` entities)

| Entity | Role |
|---|---|
| `Gemstone` | Core inventory item (diamonds, colored stones, lots share one entity) |
| `Customer` | Business customer with contact/financial info |
| `Memo` | Consignment document; owns LineItems via cascade |
| `Invoice` | Sales document; owns LineItems via cascade |
| `LineItem` | Individual stone/lot entry within a Memo or Invoice |
| `Payment` | Payment record against invoices |
| `PaymentReminder` | Scheduled AR follow-up |
| `LotTransaction` | Partial carat allocation ledger for lot stones |
| `RFIDTag` | RFID tag assignment and lifecycle tracking |
| `HistoryEvent` | Audit trail for entity changes |
| `BackupManifest` | Metadata for backup/restore operations |
| `ReconciliationRecord` | RFID scan-vs-inventory reconciliation results |

All enum fields use `String` raw values for human-readable SwiftData storage.

### Service taxonomy

See [`SERVICES-OVERVIEW.md`](SERVICES-OVERVIEW.md) for the full taxonomy with per-service details, implementation patterns, and naming conventions.

| Category | Services | Pattern |
|---|---|---|
| **Business domain** | TransactionService, MemoService, InvoiceService, LotService, ARService, SKUGenerator, HistoryLogger, ReferenceNumberGenerator, StoneDescriptionBuilder, GemstoneFilterEngine | Stateless `enum` with `static` methods; accept `ModelContext` |
| **Reporting / export** | ReportEngine, ReportExportService, PDFService, BatchPDFExporter, ShareService, RapNetExportService | Mostly stateless enums; PDFService is `@MainActor` class (WKWebView) |
| **Hardware / RFID** | RFIDManager, RFIDScanService, RFIDReconciliationService, LabelTemplateService, EPCanonical | RFIDManager is `@unchecked Sendable` class with explicit threading model |
| **Cloud / sync** | SupabaseManager, SupabaseSyncService, SupabaseAuthService, SyncDTO, SyncTracker | Observable classes; offline-first with last-write-wins sync |
| **Integration** | RapNetAPIService, RapNetSyncService | API enum + observable sync class |
| **Infrastructure / runtime** | BackupService, BackupScheduler, CloudBackupService, DemoDataService, GettingStartedService, CSVImportService | Mix of enum and class; backup includes WAL/SHM sidecar handling |
| **Protocols** | RFIDService, MemoServiceProtocol, InvoiceServiceProtocol, TransactionServiceProtocol, LabelPrintServiceProtocol | Abstract interfaces for testability |

### ViewModels (`@Observable`, `@MainActor`)

| ViewModel | Owns |
|---|---|
| `InventoryViewModel` | Shared inventory query/filter state |
| `LotInventoryViewModel` | Lot-specific inventory operations |
| `MemoListViewModel` | Memo list with pagination/fetch |
| `InvoiceListViewModel` | Invoice list management |
| `TransactionEditorViewModel` | Memo/invoice document editing |
| `CustomerListViewModel` | Customer list and search |
| `AccountingViewModel` | AR dashboard and aging |
| `DashboardViewModel` | KPI computation and dashboard state |
| `ScannerViewModel` | RFID scan session state |
| `ReconcileViewModel` | Inventory reconciliation workflow |
| `StoneFormViewModel` | Stone create/edit form state |
| `RFIDCoordinator` | App-wide RFID assign-sheet coordination |

### View organization

```
Views/
  Shell/          → AppShellView, SidebarView, OnboardingView, NavigationItem
  Dashboard/      → DashboardView, KPICardRow, QuickActionsGrid, RecentActivityList, GettingStartedChecklist
  Inventory/      → DiamondsInventoryView, GemstonesInventoryView, LotInventoryView, SoldInventoryView,
                    InventoryFilterBar(V2), GemstoneDetailPanel, BulkEditSheet, CSVImportPreviewSheet,
                    QuickEntryView, ReviewQueueView, ReconcileView
  Transactions/   → MemoListView, InvoiceListView, MemoDocumentView, InvoiceDocumentView,
                    MemoWindowView, InvoiceWindowView, TransactionEditorViewModel support views
  Customers/      → CustomerListView, CustomerDetailPanel, CustomerFormSheet, CustomerFullDetailView
  Accounting/     → AccountingView, ARDashboardView, ARAgingView, CustomerBalanceView
  Scanner/        → ScannerView, MemoReturnScanView, UnknownTagAssignSheet
  Reports/        → ReportsView, PLReportView, InventoryTurnoverView, CustomerProfitabilityView, MarginAnalysisView
  Forms/          → StoneFormView, QuickIntakeView
  Settings/       → CompanySettingsView, LabelSettingsView, RapNetSettingsView, CloudBackupSettingsView, etc.
  Auth/           → LoginView
```

---

## 6. Workflow Families

### Inventory workflows
- **Add stone:** StoneFormView → StoneFormViewModel → SKUGenerator + ModelContext insert
- **Bulk import:** CSV file → CSVImportService → preview sheet → batch insert
- **Filter/search/sort:** Per-view filter state (InventoryFilterBar/V2) applied to `@Query` results
- **Bulk edit:** Selection → BulkEditSheet → batch update
- **Detail inspect:** Row selection → GemstoneDetailPanel side panel

### Transaction workflows
- **Create memo:** MemoListView → new Memo → MemoDocumentView (separate window)
- **Memo → Invoice conversion:** Memo with accepted items → InvoiceService creates Invoice
- **Returns:** LineItem status change → TransactionService updates Gemstone status back to Available
- **Payments:** PaymentListView → Payment records against Invoice

### Gemstone status lifecycle
```
Available → On Memo → Sold
    ↑          ↓
    ←── Returned
```

### RFID workflows
- **Scan:** ScannerView → RFIDManager reads tags → ScannerViewModel processes
- **Assign:** Unknown tag → UnknownTagAssignSheet → RFIDTag created and linked to Gemstone
- **Reconcile:** ReconcileView → scan all → compare against expected inventory → ReconciliationRecord
- **Memo return scan:** MemoReturnScanView → scan returning stones → update memo line items

### Reporting workflows
- **P&L:** ReportEngine computes from paid invoices and line item costs
- **Turnover:** Current inventory as proxy (no historical snapshots)
- **Profitability:** Per-customer aggregation from invoice/payment data
- **Margin analysis:** Line-item level margin from cost vs sale price
- **Export:** ReportExportService generates CSV/PDF from report data
- See [`REPORTING-MODEL.md`](REPORTING-MODEL.md) for the full reporting model specification including formulas, status filters, COGS assumptions, proxy vs exact classification, and known limitations.

### Sync / backup workflows
- **Local backup:** BackupService copies store + WAL/SHM sidecars; CSV bundle export
- **Restore:** Safety backup → replace store → rollback on failure
- **Scheduled backup:** BackupScheduler triggers periodic backups
- **Cloud backup:** CloudBackupService pushes to remote storage
- **Supabase sync:** Offline-first, push-then-pull, last-write-wins by `updated_at`. Syncs: customers, gemstones, memos, invoices, line items, lot transactions, payments, history events, RFID tags. See [`SYNC-MODEL.md`](SYNC-MODEL.md) for the full sync model specification including identity rules, conflict model, and known risks.

---

## 7. Strong Areas

### App bootstrap / migration safety
- Custom store path avoids v1 collision
- `GemAppMigrationPlan` for schema evolution
- In-memory fallback on failure with UI alert and export/reset flow
- No silent destructive recovery

### Backup / restore
- Store copy includes WAL/SHM sidecar files
- Safety backup before restore with rollback on failure
- CSV export covers major entities
- Temp file cleanup discipline

### RFID subsystem
- Real connection/startup state machine with reconnect logic
- Explicit threading model with documented synchronization strategy
- Dedicated protocol abstraction (views never touch RFIDManager directly)
- CRC16-CCITT validation, frame buffering, session deduplication

### Desktop workflow ergonomics
- Multi-window document operation
- Unsaved-change guarding on both navigation and quit
- Keyboard shortcut coverage across all major routes
- Shell/sidebar structure tuned for repetitive business workflows

---

## 8. Drift-Prone Areas

### Inventory view sprawl
Inventory screens (diamonds, gemstones, lots, sold) each maintain their own filter/sort/search/selection/import-export state directly in views. This is the largest concentration of view-local logic and the most likely source of duplication and complexity drift.

### Architectural inconsistency
Transaction/document screens are more ViewModel-centric. Inventory and some shell-adjacent surfaces retain more logic in views. This inconsistency makes it harder to predict where state lives for any given feature.

### Scope growth beyond docs
The app's actual scope (cloud sync, auth, RapNet, API server, scheduled backups) has outgrown the original "local persistence, no server" framing. New contributors may underestimate operational complexity.

### Reporting assumptions
Some report metrics use proxies (e.g., current inventory as turnover denominator) rather than historical ledger snapshots. These business assumptions are now documented in [`REPORTING-MODEL.md`](REPORTING-MODEL.md), including the proxy vs exact classification for every metric.

### Sync conflict model
Supabase sync uses last-write-wins with business-key upserts (SKU, email, reference numbers). Identity and conflict rules are now documented in [`SYNC-MODEL.md`](SYNC-MODEL.md). Key risks include push-only entities (5 of 9 have no pull), relationship orphaning after pull, and no conflict detection or audit logging.

---

## 9. Additional Technical Notes

### Concurrency (Swift 6 strict)
- ViewModels: `@Observable`, `@MainActor`
- Business enum services: `@MainActor`
- `RFIDManager`: `@unchecked Sendable` with manual thread safety
- `PDFService`: `@MainActor` (WKWebView requirement)
- Environment key defaults: `nonisolated(unsafe) static let` for non-Sendable types

### Data store
- Path: `QDIGemstoneERP_v2.store`
- Migration: `GemAppMigrationPlan`
- Failure mode: in-memory fallback, alert, export/reset option
- Demo seeding: `DemoDataService` in DEBUG builds with `seedDemoData` flag

### Entitlements
- Hardened runtime
- App sandbox with serial port, network client/server, user-selected file read/write

---

## 10. Documentation Map

| Document | Purpose |
|---|---|
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | This file — canonical technical overview of the actual system |
| [`CLAUDE.md`](CLAUDE.md) | Coding-agent guidance: build commands, key patterns, common pitfalls |
| [`SERVICES-OVERVIEW.md`](SERVICES-OVERVIEW.md) | Full service taxonomy with per-service details, patterns, and naming conventions |
| [`SYNC-MODEL.md`](SYNC-MODEL.md) | Supabase sync specification: identity rules, conflict model, known risks |
| [`REPORTING-MODEL.md`](REPORTING-MODEL.md) | Report formulas, status filters, COGS assumptions, proxy vs exact classification |

---

## 11. Hardening Roadmap

The codebase underwent a structured hardening initiative (phase 2) that produced this documentation layer. The remaining hardening targets, in priority order:

1. **Inventory module rationalization** — consolidate duplicated filter/sort/search state across diamond/gem/lot/sold views into shared abstractions
2. **View / ViewModel boundary tightening** — push heavy view-local logic into ViewModels for the most state-heavy screens
3. **Sync guardrails** — runtime identity assertions, duplicate detection, sync audit logging (see SYNC-MODEL.md §9)
4. **Reporting UI labels** — surface proxy vs exact classification in report exports where metrics are approximation-based
5. **Performance cleanup** — move expensive computed filtering out of render paths in inventory tables

These are consolidation tasks, not rewrites. The goal is to reduce architectural unevenness while preserving the strong foundations in bootstrap safety, backup/restore, RFID subsystem, and desktop workflow ergonomics.
