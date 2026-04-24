# GEMAPP UI Testing Protocol

Status: Phase 5 complete (final consolidation)

## Overview

Automated UI testing for GEMAPP uses XCUITest (Xcode UI Testing framework) to verify navigation, keyboard shortcuts, and screen transitions. Tests run against the full app binary, interacting through the accessibility layer.

## Test Target

- **Target name:** `QDI_Gemstone_ERP_v2UITests`
- **Type:** `bundle.ui-testing` (XcodeGen)
- **Source directory:** `Tests/QDI_Gemstone_ERP_v2UITests/`
- **Scheme:** included in `QDI_Gemstone_ERP_v2` scheme test action

## Prerequisites

### macOS Accessibility Permission

UI tests require **Accessibility access** for the process running `xcodebuild` (Terminal, iTerm2, CI agent, etc.).

Grant in: **System Settings > Privacy & Security > Accessibility**

Without this permission, tests will fail with:
> "The test runner failed to initialize for UI testing. Authentication canceled."

### Code Signing

The UI test target uses ad-hoc signing with hardened runtime disabled (`ENABLE_HARDENED_RUNTIME: NO`). This is required for the XCTRunner to load the test bundle on macOS without a development team certificate.

## Running Tests

```bash
# From repo root (after xcodegen generate)

# Build and run UI tests only
xcodebuild -project QDI_Gemstone_ERP_v2.xcodeproj \
  -scheme QDI_Gemstone_ERP_v2 \
  -destination 'platform=macOS' \
  -only-testing:QDI_Gemstone_ERP_v2UITests \
  test

# Build for testing (compile only, don't run)
xcodebuild -project QDI_Gemstone_ERP_v2.xcodeproj \
  -scheme QDI_Gemstone_ERP_v2 \
  -destination 'platform=macOS' \
  build-for-testing

# Run from Xcode: Product > Test (Cmd+U) with UI test target enabled
```

## Onboarding Bypass

The app gates on onboarding (`onboardingComplete` + `companyName`). Tests bypass this via launch arguments:

```swift
app.launchArguments += ["-onboardingComplete", "YES"]
app.launchArguments += ["-companyName", "UI Test Corp"]
app.launchArguments += ["-seedDemoData", "NO"]
```

These write directly to `@AppStorage` / `UserDefaults` for the test process.

## Accessibility Identifiers

Key identifiers used by tests (and available for future tests):

### Shell / Chrome
| Identifier | Element | Location |
|---|---|---|
| `AppShellView` | Root shell container | `AppShellView.swift` |
| `SidebarView` | Sidebar container | `AppShellView.swift` |
| `ContentArea` | Main content area | `AppShellView.swift` |
| `route_title` | Header route title text | `AppShellView.swift` |

### Sidebar Navigation
| Identifier | Route |
|---|---|
| `sidebar_dashboard` | Dashboard |
| `sidebar_memos` | Memos |
| `sidebar_invoices` | Invoices |
| `sidebar_customers` | Customers |
| `sidebar_diamonds` | Diamonds |
| `sidebar_gemstones` | Gemstones |
| `sidebar_lots` | Lots |
| `sidebar_sold` | Sold |
| `sidebar_quick_intake` | Quick Intake |
| `sidebar_quick_entry` | Quick Entry |
| `sidebar_review_queue` | Review Queue |
| `sidebar_scanner` | Scanner |
| `sidebar_memo_return` | Memo Return |
| `sidebar_reconcile` | Reconcile |
| `sidebar_reports` | Reports |
| `sidebar_accounting` | Accounting |
| `sidebar_ar` | AR |

Pattern: `sidebar_\(NavigationItem.rawValue.lowercased().replacingOccurrences(of: " ", with: "_"))`

### Screen-Level Views
| Identifier | Screen | Location |
|---|---|---|
| `DashboardView` | Dashboard | `DashboardView.swift` |
| `KPICardRow` | Dashboard KPI cards grid | `KPICardRow.swift` |
| `GettingStartedChecklist` | Dashboard onboarding checklist | `GettingStartedChecklist.swift` |
| `DiamondsInventoryView` | Diamonds inventory | `DiamondsInventoryView.swift` |
| `GemstonesInventoryView` | Gemstones inventory | `GemstonesInventoryView.swift` |
| `MemoListView` | Memos list | `MemoListView.swift` |
| `InvoiceListView` | Invoices list | `InvoiceListView.swift` |
| `CustomerListView` | Customers list | `CustomerListView.swift` |
| `ReportsView` | Reports | `ReportsView.swift` |
| `ScannerView` | Scanner | `ScannerView.swift` |
| `QuickIntakeView` | Quick Intake form | `QuickIntakeView.swift` |
| `QuickEntryView` | Quick Entry spreadsheet | `QuickEntryView.swift` |
| `LotInventoryView` | Lots inventory | `LotInventoryView.swift` |
| `SoldInventoryView` | Sold inventory | `SoldInventoryView.swift` |
| `ReviewQueueView` | Review Queue | `ReviewQueueView.swift` |
| `AccountingView` | Accounting | `AccountingView.swift` |
| `ARDashboardView` | Accounts Receivable | `ARDashboardView.swift` |
| `MemoReturnScanView` | Memo Return | `MemoReturnScanView.swift` |
| `ReconcileView` | Reconcile | `ReconcileView.swift` |

## Phase 1 Coverage: Shell Smoke Suite

File: `Tests/QDI_Gemstone_ERP_v2UITests/ShellSmokeTests.swift`

### Tests (15 total)

| Test | Category | Description |
|---|---|---|
| `testAppLaunchesAndShellExists` | Launch | Verifies AppShellView exists after launch |
| `testSidebarVisibleOnLaunch` | Launch | Verifies sidebar is present |
| `testDefaultRouteIsDashboard` | Launch | Verifies default route title is "Dashboard" |
| `testSidebarNavigatesToMemos` | Sidebar | Click sidebar Memos, verify route title |
| `testSidebarNavigatesToInvoices` | Sidebar | Click sidebar Invoices, verify route title |
| `testSidebarNavigatesToCustomers` | Sidebar | Click sidebar Customers, verify route title |
| `testSidebarNavigatesToDiamonds` | Sidebar | Click sidebar Diamonds, verify route title |
| `testSidebarNavigatesToReports` | Sidebar | Click sidebar Reports, verify route title |
| `testSidebarNavigatesToSettings` | Sidebar | Click Settings button, verify route title |
| `testKeyboardShortcutCmd2NavigatesToMemos` | Keyboard | Cmd+2 navigates to Memos |
| `testKeyboardShortcutCmd5NavigatesToDiamonds` | Keyboard | Cmd+5 navigates to Diamonds |
| `testKeyboardShortcutCmd6NavigatesToGemstones` | Keyboard | Cmd+6 navigates to Gemstones |
| `testKeyboardShortcutCmd1ReturnsToDashboard` | Keyboard | Cmd+3 then Cmd+1 returns to Dashboard |
| `testContentAreaExistsOnLaunch` | Launch | Verifies content area container exists |
| `testRoundTripNavigationViaKeyboard` | Keyboard | Multi-route round trip via Cmd+4/7/8/1 |

### Build Status
- **Compiles:** Yes
- **Runs:** Requires macOS Accessibility permission for terminal process

## Phase 2 Coverage: Screen-Level Smoke Tests

File: `Tests/QDI_Gemstone_ERP_v2UITests/ScreenSmokeTests.swift`

### Tests (17 total)

| Test | Screen | Description |
|---|---|---|
| `testDashboardScreenRendersOnLaunch` | Dashboard | Verifies DashboardView exists on default route |
| `testDashboardKPICardsExist` | Dashboard | Verifies KPICardRow grid renders |
| `testDashboardGettingStartedChecklistExists` | Dashboard | Verifies GettingStartedChecklist renders |
| `testDiamondsScreenRendersAfterNavigation` | Diamonds | Navigate via ⌘5, verify DiamondsInventoryView |
| `testDiamondsScreenHasSearchField` | Diamonds | Verify search field in filter bar |
| `testGemstonesScreenRendersAfterNavigation` | Gemstones | Navigate via ⌘6, verify GemstonesInventoryView |
| `testGemstonesScreenHasSearchField` | Gemstones | Verify search field in filter bar |
| `testMemosScreenRendersAfterNavigation` | Memos | Navigate via ⌘2, verify MemoListView |
| `testMemosScreenHasNewMemoButton` | Memos | Verify "New Memo" button exists |
| `testInvoicesScreenRendersAfterNavigation` | Invoices | Navigate via ⌘3, verify InvoiceListView |
| `testInvoicesScreenHasNewInvoiceButton` | Invoices | Verify "New Invoice" button exists |
| `testCustomersScreenRendersAfterNavigation` | Customers | Navigate via ⌘4, verify CustomerListView |
| `testCustomersScreenHasAddButton` | Customers | Verify "Add Customer" button exists |
| `testReportsScreenRendersAfterNavigation` | Reports | Navigate via sidebar, verify ReportsView |
| `testReportsScreenHasReportTypePills` | Reports | Verify report type filter pills exist |
| `testScannerScreenRendersAfterNavigation` | Scanner | Navigate via ⌘0, verify ScannerView (safe, read-only) |
| `testScannerScreenHasStartButton` | Scanner | Verify Start Scanning button exists (not clicked) |
| `testNavigateAllScreensSequentially` | All | Round-trip through all screens verifying root views |

### Accessibility Identifiers Added in Phase 2
- `ScannerView` — added to `ScannerView.swift`
- `KPICardRow` — added to `KPICardRow.swift`

### Build Status
- **Compiles:** Yes (`build-for-testing` succeeds)
- **Runs:** Blocked by macOS Accessibility permission for terminal process (same as Phase 1)

## Phase 3 Coverage: Workflow Smoke Tests

File: `Tests/QDI_Gemstone_ERP_v2UITests/WorkflowSmokeTests.swift`

### Tests (27 total)

| Test | Category | Description |
|---|---|---|
| `testMemoListSurfaceOpensViaSidebar` | Memo | Open memo list via sidebar click |
| `testMemoListSurfaceOpensViaKeyboard` | Memo | Open memo list via ⌘2 |
| `testMemoListHasNewMemoButton` | Memo | Verify "New Memo" button exists |
| `testMemoListHasSearchField` | Memo | Verify search field in memo list |
| `testInvoiceListSurfaceOpensViaSidebar` | Invoice | Open invoice list via sidebar click |
| `testInvoiceListSurfaceOpensViaKeyboard` | Invoice | Open invoice list via ⌘3 |
| `testInvoiceListHasNewInvoiceButton` | Invoice | Verify "New Invoice" button exists |
| `testInvoiceListHasSearchField` | Invoice | Verify search field in invoice list |
| `testQuickIntakeOpensViaSidebar` | Quick Intake | Open Quick Intake via sidebar |
| `testQuickIntakeOpensViaKeyboard` | Quick Intake | Open Quick Intake via ⌘9 |
| `testQuickEntryOpensViaSidebar` | Quick Entry | Open Quick Entry via sidebar |
| `testQuickEntryHasCategoryPicker` | Quick Entry | Verify stone type category picker exists |
| `testLotsScreenRendersViaSidebar` | Lots | Navigate to Lots via sidebar |
| `testLotsScreenRendersViaKeyboard` | Lots | Navigate to Lots via ⌘7 |
| `testSoldScreenRendersViaSidebar` | Sold | Navigate to Sold via sidebar |
| `testSoldScreenRendersViaKeyboard` | Sold | Navigate to Sold via ⌘8 |
| `testSoldScreenHasSearchField` | Sold | Verify search field in sold inventory |
| `testReviewQueueRendersViaSidebar` | Review Queue | Navigate to Review Queue via sidebar |
| `testReviewQueueHasSearchField` | Review Queue | Verify search field in review queue |
| `testAccountingScreenRendersViaSidebar` | Accounting | Navigate to Accounting via sidebar |
| `testARScreenRendersViaSidebar` | AR | Navigate to AR via sidebar |
| `testMemoReturnRendersViaSidebar` | Memo Return | Navigate to Memo Return via sidebar |
| `testReconcileRendersViaSidebar` | Reconcile | Navigate to Reconcile via sidebar |
| `testDiamondsSearchFieldAcceptsInput` | Search | Type in diamonds search field, verify input |
| `testGemstonesSearchFieldAcceptsInput` | Search | Type in gemstones search field, verify input |
| `testWorkflowRoundTripMemoToInvoiceAndBack` | Round-Trip | Memo → Invoice → Memo → Dashboard |
| `testWorkflowRoundTripInventoryScreens` | Round-Trip | Diamonds → Gemstones → Lots → Sold → Dashboard |
| `testWorkflowRoundTripSidebarOnlyScreens` | Round-Trip | All sidebar-only screens sequentially |
| `testFullNavigationRoundTripPreservesShellStability` | Round-Trip | All routes via keyboard + sidebar, verify shell chrome |

### Accessibility Identifiers Added in Phase 3
- `QuickIntakeView` — added to `QuickIntakeView.swift`
- `QuickEntryView` — added to `QuickEntryView.swift`
- `LotInventoryView` — added to `LotInventoryView.swift`
- `SoldInventoryView` — added to `SoldInventoryView.swift`
- `ReviewQueueView` — added to `ReviewQueueView.swift`
- `AccountingView` — added to `AccountingView.swift`
- `MemoReturnScanView` — added to `MemoReturnScanView.swift`
- `ReconcileView` — added to `ReconcileView.swift`

### Build Status
- **Compiles:** Yes (`build-for-testing` succeeds)
- **Runs:** Requires macOS Accessibility permission for terminal process (same as Phase 1/2)

## Phase 4: Evidence Capture & Protocol Hardening

### Screenshot Capture on Failure

File: `Tests/QDI_Gemstone_ERP_v2UITests/ScreenshotCapture.swift`

All UI test classes now auto-capture a screenshot when a test fails. The screenshot is attached to the `.xcresult` bundle and visible in Xcode's Test Report navigator.

**How it works:**
- `ScreenshotCapture.swift` adds an `XCTestCase` extension with two methods:
  - `captureScreenshotOnFailure(app:)` — called in `tearDownWithError()`, attaches a screenshot only when the test has failed
  - `captureScreenshot(name:lifetime:app:)` — explicit evidence capture at any point during a test
- All three test classes (`ShellSmokeTests`, `ScreenSmokeTests`, `WorkflowSmokeTests`) call `captureScreenshotOnFailure(app: app)` in their `tearDownWithError()`

**Viewing screenshots:**
```bash
# After running tests, open the xcresult bundle:
open Build/Logs/Test/*.xcresult

# Or export via CLI:
xcrun xcresulttool get --path Build/Logs/Test/*.xcresult --format json
```

### Accessibility Identifiers Added in Phase 4

| Identifier | Element | Location |
|---|---|---|
| `sidebar_settings` | Settings sidebar button | `SidebarView.swift` |
| `button_cancel_stone` | Cancel button in stone form | `StoneFormView.swift` |
| `button_save_stone` | Save button in stone form | `StoneFormView.swift` |
| `button_save_continue_stone` | Save & Continue button in stone form | `StoneFormView.swift` |
| `button_cancel_intake` | Cancel button in quick intake | `QuickIntakeView.swift` |
| `button_save_intake` | Save button in quick intake | `QuickIntakeView.swift` |
| `button_save_new_intake` | Save & New button in quick intake | `QuickIntakeView.swift` |

### Build Status
- **Compiles:** Yes (`build-for-testing` succeeds)
- **Runs:** Requires macOS Accessibility permission for terminal process (same as Phase 1/2/3)

## Phase 5: Final Consolidation

Phase 5 verified all prior work (Phases 1–4) is clean, accurate, and buildable:

- **UI-TESTING.md** reviewed and updated to reflect accurate test counts, file locations, and accessibility identifiers
- **CLAUDE.md** updated to reference the 89-test suite (59 UI + 30 unit) instead of the outdated "No tests exist yet"
- **Test file organization** confirmed: 4 UI test files in `Tests/QDI_Gemstone_ERP_v2UITests/`, 3 unit test files in `Tests/QDI_Gemstone_ERP_v2Tests/`
- **Build verification** confirmed `build-for-testing` compiles both test targets with 0 errors
- No product code changes — consolidation and documentation only

### Build Status
- **Compiles:** Yes (`build-for-testing` succeeds)
- **Runs:** Requires macOS Accessibility permission for terminal process (same as prior phases)

---

## Overnight Verification Checklist

Manual checklist for verifying UI test health after significant changes. Run before merging or after overnight CI.

### Pre-Run

- [ ] macOS Accessibility permission granted to terminal/CI process
- [ ] `xcodegen generate` run after any file additions
- [ ] DerivedData clean if switching branches: `rm -rf ~/Library/Developer/Xcode/DerivedData/QDI_Gemstone_ERP_v2-*`
- [ ] No stale `.xcodeproj` — regenerate if `project.yml` changed

### Build

- [ ] `xcodebuild build-for-testing` completes with 0 errors
- [ ] No new warnings in UI test target

### Test Execution

```bash
xcodebuild -project QDI_Gemstone_ERP_v2.xcodeproj \
  -scheme QDI_Gemstone_ERP_v2 \
  -destination 'platform=macOS' \
  -only-testing:QDI_Gemstone_ERP_v2UITests \
  -resultBundlePath TestResults.xcresult \
  test
```

- [ ] All 59 UI tests pass (15 shell + 17 screen + 27 workflow)
- [ ] No flaky tests (re-run once if a single test fails to confirm)
- [ ] Test duration under 5 minutes total

### Evidence Review

- [ ] Open `TestResults.xcresult` in Xcode — verify no failure screenshots
- [ ] If failures exist: screenshots attached and clearly show the failure state
- [ ] Spot-check 2-3 test logs for correct route title assertions

### Smoke Validation (manual, 2 minutes)

- [ ] Launch app manually — onboarding appears (fresh) or dashboard appears (configured)
- [ ] Click through 3+ sidebar items — route title updates correctly
- [ ] Press ⌘1 through ⌘5 — keyboard shortcuts navigate correctly
- [ ] Open Quick Intake (⌘9) — form renders with Save/Cancel buttons

### Post-Run

- [ ] Archive `TestResults.xcresult` if this is a release verification
- [ ] Note any new flaky tests in this document's Troubleshooting section
- [ ] If tests were added: update test count in this checklist (currently 59)

---

## Future Phases

### Phase 6: Document Window Tests
- Memo document opens via sidebar
- Invoice document opens and renders
- Unsaved changes guard triggers on navigation

### Phase 7: Settings & Reports
- Company settings form
- Report generation
- Cloud backup settings

## Adding New Tests

1. Add accessibility identifiers to the target view (only where needed)
2. Add test methods to `ShellSmokeTests.swift`, `ScreenSmokeTests.swift`, `WorkflowSmokeTests.swift`, or create a new test class
3. Use `app.launchArguments` to set any required defaults
4. Use `waitForExistence(timeout:)` and `XCTNSPredicateExpectation` for async UI
5. In new test classes, add `captureScreenshotOnFailure(app: app)` in `tearDownWithError()` (from `ScreenshotCapture.swift`)
6. Use `captureScreenshot(name:)` for explicit evidence at key checkpoints
7. Run `xcodegen generate` if you added new test files
8. Build and test: `xcodebuild ... -resultBundlePath TestResults.xcresult test`

## Troubleshooting

### "Authentication canceled" / "System authentication is running"
Grant Accessibility access to your terminal app in System Settings > Privacy & Security > Accessibility.

### "Different Team IDs" / code signing errors
Clean DerivedData: `rm -rf ~/Library/Developer/Xcode/DerivedData/QDI_Gemstone_ERP_v2-*`
Then rebuild: `xcodegen generate && xcodebuild ... build-for-testing`

### Tests can't find UI elements
1. Check the accessibility identifier is spelled correctly
2. Use `app.debugDescription` to dump the accessibility tree
3. Verify onboarding bypass arguments are set in `setUp()`
