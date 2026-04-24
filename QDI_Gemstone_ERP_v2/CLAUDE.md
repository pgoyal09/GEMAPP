# QDI Gemstone ERP v2

Native macOS desktop ERP for Quality Diajewels Inc. — gemstone inventory, transactions, RFID, reporting, backup, and Supabase cloud sync. See `ARCHITECTURE.md` for the full technical overview.

## Tech Stack

- **SwiftUI** + **SwiftData** (local-first persistence; Supabase sync/auth optional)
- **Swift 6** with `SWIFT_STRICT_CONCURRENCY: complete`
- **macOS 14.0+** deployment target
- **XcodeGen** (`project.yml` → `.xcodeproj`). Run `xcodegen generate` after changing project structure.
- **ORSSerialPort** (SPM) for USB-serial RFID hardware communication

## Build

```bash
# Generate Xcode project (required after adding/removing files or changing project.yml)
cd /Users/priyank/Desktop/gemapp/QDI_Gemstone_ERP_v2
xcodegen generate

# Build
xcodebuild -project QDI_Gemstone_ERP_v2.xcodeproj -scheme QDI_Gemstone_ERP_v2 -destination 'platform=macOS' build
```

No tests exist yet. No linter configured.

## Architecture

**MVVM + Service Layer**: View → ViewModel → Service → Model

- **ViewModels** (`@Observable`, `@MainActor`): Own UI state (search text, selections, form fields). Never touch `ModelContext` directly for business logic — delegate to services.
- **Services**: Business domain services are stateless `enum` types with `static` methods (TransactionService, MemoService, InvoiceService, LotService, SKUGenerator, etc.) that accept `ModelContext`. Infrastructure/cloud services (PDFService, SupabaseSyncService, CloudBackupService, RFIDManager) are observable classes. See `ARCHITECTURE.md` § Service taxonomy for full classification.
- **Models** (`@Model`): SwiftData entities. All enums are `String`-backed `Codable` for human-readable storage.
- **DesignSystem**: Shared components (GlassCard, FilterPill, StatusBadge, etc.), button styles, view modifiers, and theme constants. All views use these — never inline raw colors/fonts.

## Directory Structure

```
App/              → @main entry point, AppConstants, WindowGroup definitions
API/              → Embedded local API server
Models/           → SwiftData @Model classes (12 entity types)
Models/Enums/     → String-backed Codable enums (StoneType, GemstoneStatus, etc.)
Services/         → Business logic (enum + static), cloud/sync, backup, PDF, reporting
Services/RFID/    → RFIDManager (hardware driver), RFIDScanService, RFIDService protocol
Services/Supabase/→ SupabaseManager, SyncService, AuthService, SyncDTO/Tracker
Services/RapNet/  → RapNet API and sync integration
Utilities/        → NavigationGuard, DocumentDirtyTracker, CurrencyFormatter, extensions
DesignSystem/     → Theme (AppColors, AppTypography, AppSpacing), Components, ButtonStyles, Modifiers, TableKit
ViewModels/       → @Observable view models, RFIDCoordinator
Views/            → SwiftUI views organized by feature (Shell, Dashboard, Inventory, Transactions, Customers, Scanner, Accounting, Forms, Reports, Settings, Auth)
Resources/        → Assets.xcassets, entitlements
Tests/            → Test target (minimal)
```

## Key Patterns

### SwiftData Models
- All enum fields use `String` raw values (e.g., `StoneGrouping: String, Codable`)
- `#Predicate` macros cannot use enum member access — compare against raw value strings: `$0.grouping == "L"` not `$0.grouping == .lot`
- Relationships use `@Relationship(deleteRule: .cascade)` where parent owns children (Memo→LineItems, Invoice→LineItems)
- 12 model types in the container: Gemstone, Customer, Memo, Invoice, LineItem, RFIDTag, LotTransaction, HistoryEvent, Payment, PaymentReminder, BackupManifest, ReconciliationRecord

### Concurrency (Swift 6 Strict)
- ViewModels and services are `@MainActor`
- `RFIDManager` is `@unchecked Sendable` — it manages thread safety via serial port delegate callbacks
- `PDFService` is `@MainActor` because WKWebView requires main thread
- Environment key default values use `nonisolated(unsafe) static let` for non-Sendable types
- Module-level constants use `nonisolated(unsafe)` when mutable init is needed (e.g., `mach_timebase_info`)

### Multi-Window
- Three WindowGroups: main app, memo document, invoice document
- Memo/Invoice windows open via `openWindow(value: PersistentIdentifier)`
- Each document window gets its own `DocumentDirtyTracker` via environment
- `NavigationGuard` prevents sidebar navigation when there are unsaved changes

### Design System
- Dark glass-morphism theme: `AppColors.glass*` for card backgrounds/borders
- Primary color: cyan `#38bdf8` (`AppColors.primary`)
- Always use `AppTypography`, `AppSpacing`, `AppCornerRadius` — never hardcode
- `.appBackground()` modifier for window/sheet backgrounds
- `.glassField()` modifier for text fields
- `.glassTable()` modifier for table containers
- Button styles: `.gradient` / `.outline`

### RFID Hardware
- Silion protocol over USB-Serial (FTDI chip)
- Binary frame format with CRC16-CCITT checksums
- `RFIDService` protocol abstracts hardware — views never touch `RFIDManager` directly
- `RFIDCoordinator` (environment object) manages app-wide assign-sheet state
- `EPCanonical` normalizes raw hex EPC strings

### SKU Format
`TYPE-SHAPE-GROUP-NNN` (e.g., `DI-RD-S-001`)
- TYPE: 2-char from `StoneType.skuCode`
- SHAPE: 2-char from `StoneShape.skuCode(from:)`
- GROUP: 1-char from `StoneGrouping.skuCode` (S/P/L)
- NNN: auto-incrementing 3-digit sequence per prefix

### Gemstone Status Workflow
```
Available → On Memo → Sold
    ↑          ↓
    ←── Returned
```

### Lot Inventory
- Lots are `Gemstone` with `grouping == .lot`
- Partial carat allocations tracked via `LotTransaction` ledger
- `lockedCostPerCarat` captured at transaction time for accurate profit calc
- Weighted-average cost via `LotService`

## Environment Keys

Custom environment values (all declared in their respective files):
- `\.rfidService` → `RFIDService?` (in `Services/RFID/RFIDService.swift`)
- `\.rfidCoordinator` → `RFIDCoordinator?` (in `Services/RFID/RFIDService.swift`)
- `\.navigationGuard` → `NavigationGuard` (in `Utilities/NavigationGuard.swift`)
- `\.documentDirtyTracker` → `DocumentDirtyTracker` (in `Utilities/DocumentDirtyTracker.swift`)

## Common Pitfalls

- **Don't duplicate environment keys.** Each key struct + EnvironmentValues extension must exist in exactly one file.
- **Don't add `nilIfEmpty` or other common extensions locally** — they're in `Utilities/Extensions/String+Helpers.swift`.
- **Don't use `.frame(width:minHeight:)`** — `width` and `minHeight` are from different overloads. Use `minWidth` with `minHeight`.
- **FilterPill** parameter names are `title:isActive:action:` (not `label:isSelected:`).
- **`RFIDTag` init** uses `epcCurrent` and `tidLastVerified` (not `epcOriginal` or `tid`).
- **`StoneType` has 20 cases** including `.other`. Core types: diamond, emerald, ruby, sapphire, tanzanite. Extended: alexandrite, amethyst, aquamarine, citrine, garnet, morganite, opal, paraiba, peridot, spinel, topaz, tourmaline, tsavorite, zircon, other.
- **PDF generation** is `@MainActor` — don't wrap calls in `DispatchQueue.main.async`.
- **SwiftData store** uses `QDIGemstoneERP_v2.store` (not `default.store`) to avoid colliding with the v1 app. On migration failure the store is automatically deleted and recreated — all data is re-seeded via `DemoDataService`.
