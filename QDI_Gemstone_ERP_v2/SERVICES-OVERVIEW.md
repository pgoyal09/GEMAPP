# GEMAPP Service Taxonomy

Classification of every service in `Services/` by role, implementation pattern, and ownership.

---

## Taxonomy Categories

| Category | Description | Typical Pattern |
|---|---|---|
| **Business Domain** | Core business logic — transactions, inventory rules, costing, AR, SKU generation | Stateless `enum` with `static` methods; accepts `ModelContext` |
| **Infrastructure / Runtime** | App lifecycle support — backup, scheduling, demo seeding, onboarding helpers | Mix of `enum` (stateless) and `@Observable class` (stateful schedulers) |
| **Cloud / Sync** | Supabase auth, sync, connection management | Observable classes; offline-first push-then-pull |
| **Hardware / RFID** | RFID reader communication, tag processing, scan workflows, label printing | `RFIDManager` is `@unchecked Sendable` class; others are stateless enums |
| **Reporting / Export** | Report computation, PDF/CSV generation, sharing, RapNet export | Mostly stateless enums; `PDFService` is `@MainActor` class (WKWebView) |
| **Protocols** | Abstract interfaces for testability and hardware abstraction | Swift `protocol` declarations |

---

## Full Service Inventory

### Business Domain

| Service | File | Pattern | Purpose |
|---|---|---|---|
| `TransactionService` | `Services/TransactionService.swift` | `enum`, conforms to `TransactionServiceProtocol` | Memo/invoice creation, line item management, status transitions, returns |
| `MemoService` | `Services/MemoService.swift` | `enum`, conforms to `MemoServiceProtocol` | Memo lifecycle — create, finalize, return, cancel, close |
| `InvoiceService` | `Services/InvoiceService.swift` | `enum`, conforms to `InvoiceServiceProtocol` | Invoice lifecycle — create from memo, payment application, status management |
| `LotService` | `Services/LotService.swift` | `enum` | Lot partial-carat allocation, weighted-average cost, transaction ledger |
| `ARService` | `Services/ARService.swift` | `enum` (+ supporting structs) | Accounts receivable aging buckets, customer balance computation |
| `SKUGenerator` | `Services/SKUGenerator.swift` | `enum` | Auto-incrementing SKU generation (`TYPE-SHAPE-GROUP-NNN`) |
| `ReferenceNumberGenerator` | `Services/ReferenceNumberGenerator.swift` | `enum` | Auto-incrementing memo/invoice reference numbers |
| `HistoryLogger` | `Services/HistoryLogger.swift` | `enum` | Audit trail — logs HistoryEvent records for entity changes |
| `StoneDescriptionBuilder` | `Services/StoneDescriptionBuilder.swift` | `enum` | Builds human-readable line item descriptions from stone properties |
| `GemstoneFilterEngine` | `Services/GemstoneFilterEngine.swift` | `enum`, `@MainActor` | Stateless filtering and sorting engine for gemstone arrays |

### Infrastructure / Runtime

| Service | File | Pattern | Purpose |
|---|---|---|---|
| `BackupService` | `Services/BackupService.swift` | `enum` | Local store backup (including WAL/SHM sidecars), CSV export, restore with rollback |
| `BackupScheduler` | `Services/BackupScheduler.swift` | `final class`, `@Observable`, `@MainActor` | Timed automatic backup scheduling with configurable intervals |
| `CloudBackupService` | `Services/CloudBackupService.swift` | `final class`, `@Observable` | Remote/cloud backup operations |
| `DemoDataService` | `Services/DemoDataService.swift` | `struct` | Seeds demo data in DEBUG builds |
| `GettingStartedService` | `Services/GettingStartedService.swift` | `enum` (+ `GettingStartedItem` enum) | First-run checklist tracking via UserDefaults |
| `CSVImportService` | `Services/CSVImportService.swift` | `enum` | Parses and validates CSV files for bulk gemstone import |

### Cloud / Sync

| Service | File | Pattern | Purpose |
|---|---|---|---|
| `SupabaseManager` | `Services/Supabase/SupabaseManager.swift` | `final class`, `Sendable` | Supabase client singleton and connection management |
| `SupabaseSyncService` | `Services/Supabase/SupabaseSyncService.swift` | `final class`, `@Observable` | Offline-first sync engine — push then pull, last-write-wins by `updated_at` |
| `SupabaseAuthService` | `Services/Supabase/SupabaseAuthService.swift` | `final class`, `@Observable` | Supabase authentication (sign in, sign out, session management) |
| `SyncDTO` | `Services/Supabase/SyncDTO.swift` | Data transfer structs | Codable structs mapping SwiftData models to Supabase table rows |
| `SyncTracker` | `Services/Supabase/SyncTracker.swift` | Supporting type | Tracks per-entity sync timestamps and state |

### Hardware / RFID

| Service | File | Pattern | Purpose |
|---|---|---|---|
| `RFIDManager` | `Services/RFID/RFIDManager.swift` | `final class`, `@unchecked Sendable`, `ObservableObject` | Hardware driver — Silion protocol over USB-serial, connection state machine, frame parsing, CRC validation |
| `RFIDScanService` | `Services/RFID/RFIDScanService.swift` | `enum` | Tag processing logic during scan sessions |
| `RFIDReconciliationService` | `Services/RFID/RFIDReconciliationService.swift` | `enum` | Compares scanned tags against expected inventory, produces ReconciliationRecords |
| `LabelTemplateService` | `Services/RFID/LabelTemplateService.swift` | `enum`, conforms to `LabelPrintServiceProtocol` | RFID label layout and printing templates |
| `EPCanonical` | `Services/RFID/EPCanonical.swift` | Utility type | Normalizes raw hex EPC strings to canonical form |

### Reporting / Export

| Service | File | Pattern | Purpose |
|---|---|---|---|
| `ReportEngine` | `Services/ReportEngine.swift` | `enum` (+ report data structs) | In-process report computation — P&L, turnover, profitability, margin analysis |
| `ReportExportService` | `Services/ReportExportService.swift` | `enum` | Exports report data to CSV format |
| `PDFService` | `Services/PDFService.swift` | `final class`, `@MainActor` | HTML-to-PDF rendering via WKWebView for memo/invoice documents |
| `BatchPDFExporter` | `Services/BatchPDFExporter.swift` | `enum`, `@MainActor` | Generates PDFs for multiple documents into a single output folder |
| `ShareService` | `Services/ShareService.swift` | `enum` | macOS system sharing (email, AirDrop, Messages) via NSSharingServicePicker |
| `RapNetExportService` | `Services/RapNetExportService.swift` | `enum` | Exports diamond data to RapNet-compatible CSV format |

### Integration (External APIs)

| Service | File | Pattern | Purpose |
|---|---|---|---|
| `RapNetAPIService` | `Services/RapNet/RapNetAPIService.swift` | `enum` | RapNet REST API client for diamond listing/sync |
| `RapNetSyncService` | `Services/RapNet/RapNetSyncService.swift` | `final class`, `@Observable` | Orchestrates RapNet sync — push listings, pull updates |

### Protocols

| Protocol | File | Purpose |
|---|---|---|
| `TransactionServiceProtocol` | `Services/Protocols/TransactionServiceProtocol.swift` | Abstract interface for transaction operations |
| `MemoServiceProtocol` | `Services/Protocols/MemoServiceProtocol.swift` | Abstract interface for memo lifecycle |
| `InvoiceServiceProtocol` | `Services/Protocols/InvoiceServiceProtocol.swift` | Abstract interface for invoice lifecycle |
| `LabelPrintServiceProtocol` | `Services/Protocols/LabelPrintServiceProtocol.swift` | Abstract interface for label printing |
| `RFIDService` | `Services/RFID/RFIDService.swift` | Abstract interface for RFID hardware — views never touch `RFIDManager` directly |

---

## Implementation Pattern Conventions

### When to use each pattern

| Pattern | When to use | Examples |
|---|---|---|
| Stateless `enum` + `static` methods | Pure business logic that operates on ModelContext or value inputs with no retained state | TransactionService, MemoService, LotService, SKUGenerator |
| `@Observable final class` | Service that owns mutable state observed by UI (sync progress, scheduler timers, connection status) | SupabaseSyncService, BackupScheduler, RapNetSyncService |
| `@MainActor` class | Service that requires main-thread APIs (WKWebView, NSSharingService) | PDFService |
| `@unchecked Sendable` class | Service managing its own thread safety outside Swift concurrency (hardware I/O, serial port callbacks) | RFIDManager |
| `protocol` | When views or tests need to substitute implementations (hardware abstraction, service mocking) | RFIDService, TransactionServiceProtocol |

### Naming conventions

| Suffix | Meaning |
|---|---|
| `*Service` | Business logic or operational capability |
| `*Manager` | Long-lived stateful object managing a resource or connection |
| `*Scheduler` | Time-based trigger for other services |
| `*Engine` | Computation-heavy stateless processor (reports, filters) |
| `*Builder` | Constructs formatted output from domain inputs |
| `*Generator` | Produces identifiers or reference numbers |
| `*Exporter` | Formats and outputs data for external consumption |

---

## Folder Structure

```
Services/
├── TransactionService.swift      # Business Domain
├── MemoService.swift             # Business Domain
├── InvoiceService.swift          # Business Domain
├── LotService.swift              # Business Domain
├── ARService.swift               # Business Domain
├── SKUGenerator.swift            # Business Domain
├── ReferenceNumberGenerator.swift # Business Domain
├── HistoryLogger.swift           # Business Domain
├── StoneDescriptionBuilder.swift # Business Domain
├── GemstoneFilterEngine.swift    # Business Domain
├── BackupService.swift           # Infrastructure
├── BackupScheduler.swift         # Infrastructure
├── CloudBackupService.swift      # Infrastructure
├── DemoDataService.swift         # Infrastructure
├── GettingStartedService.swift   # Infrastructure
├── CSVImportService.swift        # Infrastructure
├── ReportEngine.swift            # Reporting / Export
├── ReportExportService.swift     # Reporting / Export
├── PDFService.swift              # Reporting / Export
├── BatchPDFExporter.swift        # Reporting / Export
├── ShareService.swift            # Reporting / Export
├── RapNetExportService.swift     # Reporting / Export
├── Protocols/                    # Service Protocols
│   ├── TransactionServiceProtocol.swift
│   ├── MemoServiceProtocol.swift
│   ├── InvoiceServiceProtocol.swift
│   └── LabelPrintServiceProtocol.swift
├── RFID/                         # Hardware / RFID
│   ├── RFIDManager.swift
│   ├── RFIDScanService.swift
│   ├── RFIDReconciliationService.swift
│   ├── RFIDService.swift         # Protocol
│   ├── LabelTemplateService.swift
│   └── EPCanonical.swift
├── RapNet/                       # Integration (External API)
│   ├── RapNetAPIService.swift
│   └── RapNetSyncService.swift
└── Supabase/                     # Cloud / Sync
    ├── SupabaseManager.swift
    ├── SupabaseSyncService.swift
    ├── SupabaseAuthService.swift
    ├── SyncDTO.swift
    └── SyncTracker.swift
```

---

## Known Taxonomy Issues

### Minor naming inconsistencies (documented, not changed)

1. **`ARService`** — The name `ARService` is ambiguous between "Accounts Receivable" and "Augmented Reality". In context it is clearly Accounts Receivable, but the prefix is non-obvious to new contributors. A clearer name would be `AccountsReceivableService`, but the current name is used consistently throughout the codebase and renaming has moderate blast radius across views, view models, and tests.

2. **`EPCanonical`** — Not a "service" in any conventional sense; it is a utility type for EPC string normalization. It lives in `Services/RFID/` because it is only used by RFID workflows, but semantically it is closer to a utility/extension. Low priority to move.

3. **`SyncDTO`** and `SyncTracker` — These are data/support types rather than services, but they live alongside the sync services they support. This is reasonable co-location and not worth separating.

4. **`GettingStartedService`** — Contains both a `GettingStartedItem` enum (data model) and a `GettingStartedService` enum (logic). The data model could live in `Models/` but the coupling is tight and the file is small.

---

## Cross-References

- **Architecture overview:** [`ARCHITECTURE.md`](ARCHITECTURE.md) § Service taxonomy table
- **Sync model details:** [`SYNC-MODEL.md`](SYNC-MODEL.md)
- **Reporting model details:** [`REPORTING-MODEL.md`](REPORTING-MODEL.md)
- **Coding agent guidance:** [`CLAUDE.md`](CLAUDE.md) § Key Patterns
