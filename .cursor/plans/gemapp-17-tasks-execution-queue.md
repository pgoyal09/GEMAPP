# GEMAPP 17-Task Execution Queue

## 1. Needed Changes (Summary)

1. **SKU soft lock** – Confirm prompt on manual SKU change; validate no duplicate exists.
2. **Stone type autocomplete** – Dropdown only on button press; show autocomplete hint in gray inline.
3. **Stone status** – Remove manual status picker in edit mode.
4. **Certificate Image Choose** – Fix non-functioning Choose button (fileImporter binding/presentation).
5. **Stone review screen** – Align layout with edit screen for consistency.
6. **Leave without saving** – Extend to MemosView and InvoiceListView (NavigationGuard).
7. **Treatment default** – Empty string, not "None".
8. **Save + Next default** – Enter triggers Save+Next; prevent duplicate stone creation on repeated Save.
9. **Pair dimensions** – Show second L×W×D row when Pair selected.
10. **Quick Intake layout** – Reduce empty space; save buttons bottom-right.
11. **Descriptor expansion** – Multiline descriptor rows expand for visibility.
12. **Dashboard Total Value** – Fix stuck-at-zero (investigate MemoStatus predicate / openLineItems).
13. **History customer** – Include "on memo to X" / "sold to X" in event description.
14. **Customer On Memo / Past Purchases** – List with columns; card sections.
15. **Memo delete crash** – Fix SwiftData detached-backing fault (defer access after delete).
16. **Lot descriptor** – Add Dimensions and Color for Lot grouping.
17. **Dimensions format** – Use exact decimals entered; append " mm".

---

## 2. Implementation Approach

**Order rationale:** Fix crashes and data bugs first (15, 12); then UX/UI (1–11, 13–14, 16–17). Group related changes.

**Patterns:** Follow existing `@State` / `@Binding`, `modelContext`, `NotificationCenter`, `NavigationGuard`. Use `.alert`, `.fileImporter` per current usage.

---

## 3. Execution Queue

### Step 1: SKU soft lock in stone editing
- **Goal:** On manual SKU change, show "Are you sure you want to change the SKU?"; on confirm, check uniqueness; if exists show "This SKU already exists. Please try another."
- **Files:** `StoneFormView.swift`, `SKUGenerator.swift` (add `skuExists(sku:modelContext:)` if needed)
- **Acceptance:** Edit stone, change SKU, get confirmation; duplicate SKU shows error.
- **Tests:** Build; manual test edit flow.
- **Risks:** Edit mode only; intake uses auto-SKU.

### Step 2: Stone type autocomplete – dropdown on button, gray inline hint
- **Goal:** Replace auto-dropdown with: (a) button to show options, (b) inline gray autocomplete hint in field.
- **Files:** `AutocompleteFieldView.swift` (or new variant)
- **Acceptance:** No dropdown on focus/typing; button shows list; gray suggestion in field.
- **Tests:** Build; verify stone type field.
- **Risks:** Affects all AutocompleteFieldView usages.

### Step 3: Remove stone status manual change in edit
- **Goal:** Hide or disable status picker in edit mode; status managed by system.
- **Files:** `StoneFormView.swift` (editHeaderSection)
- **Acceptance:** Edit screen has no status picker.
- **Tests:** Build.
- **Risks:** Low.

### Step 4: Fix Certificate Image Choose button
- **Goal:** Choose button opens file picker and sets path.
- **Files:** `StoneFormView.swift` (fileImporter, showCertImagePicker)
- **Acceptance:** Choose opens picker; selection updates path.
- **Tests:** Build; test file picker.
- **Risks:** macOS sandbox; security-scoped resources.

### Step 5: Stone review screen layout
- **Goal:** Make review layout match edit screen cleanliness (sections, spacing, structure).
- **Files:** `StoneFormView.swift` (intakeReviewBody / review mode)
- **Acceptance:** Review screen visually aligned with edit.
- **Tests:** Build; compare screens.
- **Risks:** Subjective; avoid breaking review flow.

### Step 6: Leave without saving for memos/invoices
- **Goal:** MemosView and InvoiceListView report dirty state to NavigationGuard; sidebar nav prompts.
- **Files:** `MemosView.swift`, `InvoiceListView.swift`, `AppShellView.swift`, `NavigationGuard.swift`
- **Acceptance:** Editing memo/invoice in-shell, then sidebar nav → prompt.
- **Tests:** Build; test navigation.
- **Risks:** MemosView/InvoiceListView are list views; editing happens in windows. Need to identify "dirty" state for in-shell content (e.g. create-but-unsaved).

### Step 7: Treatment field empty default
- **Goal:** Default `treatment` to ""; remove "None" placeholder or default.
- **Files:** `StoneFormView.swift`, `@AppStorage("QuickIntake.lastTreatment")`
- **Acceptance:** New stone shows empty treatment; no "None".
- **Tests:** Build.
- **Risks:** AppStorage may need migration for lastTreatment.

### Step 8: Save+Next default on Enter; prevent duplicate saves
- **Goal:** Enter triggers Save+Next; guard against creating multiple stones on repeated Save.
- **Files:** `StoneFormView.swift` (saveButtons, performSave, keyboardShortcut)
- **Acceptance:** Enter → Save+Next; double-Save does not create duplicate.
- **Tests:** Build; test quick intake.
- **Risks:** performSave(stay:true) for Save; stay:false clears form – ensure no double-insert.

### Step 9: Pair – second L×W×D row
- **Goal:** When Pair selected, show second dimension row (L×W×D).
- **Files:** `StoneFormView.swift` (deferredSection, dimension fields)
- **Acceptance:** Pair shows two dimension rows; Single/Lot show one.
- **Tests:** Build.
- **Risks:** Model may need second set of dimensions (length2, width2, height2?) – verify schema.

### Step 10: Quick Intake layout
- **Goal:** Reduce empty space; move save buttons to bottom-right.
- **Files:** `StoneFormView.swift` (intakeReviewBody, row layout, saveButtons)
- **Acceptance:** Denser layout; save controls bottom-right.
- **Tests:** Build.
- **Risks:** Layout preference.

### Step 11: Descriptor line expansion
- **Goal:** Multiline descriptor expands row height; only when line added within same item.
- **Files:** `EditableLineItemRow.swift`, `LineItemColumnLayout`, memo/invoice line tables
- **Acceptance:** Long descriptors visible; row expands for multiline.
- **Tests:** Build; add item with multiline desc.
- **Risks:** Table row height; lineLimit handling.

### Step 12: Dashboard Total Value on Memo
- **Goal:** Fix total stuck at zero – verify predicate, openLineItems, notification refresh.
- **Files:** `DashboardViewModel.swift`, `Memo.swift`, `DashboardView.swift`
- **Acceptance:** Total Value on Memo shows correct sum.
- **Tests:** Build; add stones to memo; check dashboard.
- **Risks:** MemoStatus vs effectiveStatus; openLineItems definition.

### Step 13: History – who on memo / sold to
- **Goal:** eventDescription includes customer name for sentToCustomer and sold.
- **Files:** `HistoryLogger.swift`, callers of `logEvent` (TransactionViewModel, TransactionEditorView, etc.)
- **Acceptance:** History shows "On memo to John" / "Sold to John".
- **Tests:** Build; check history after memo/sale.
- **Risks:** Need customer context at log sites.

### Step 14: Customer On Memo / Past Purchases list
- **Goal:** Replace cards with tables: columns Memo/Invoice#, Descriptor, Date, Value; sections On Memo, Past Purchases as cards.
- **Files:** `CustomerDetailView.swift`, `Memo.swift`, `Invoice.swift`, `LineItem.swift`
- **Acceptance:** Two card sections; each contains a table with specified columns.
- **Tests:** Build; view customer with memos/invoices.
- **Risks:** Data shape – line items per memo/invoice.

### Step 15: Fix memo delete crash
- **Goal:** Resolve "backing data was detached" when deleting memo.
- **Files:** `MemosView.swift` (MemoDocumentView deleteMemo), `MemoDetailView.swift`
- **Acceptance:** Delete memo without crash.
- **Tests:** Build; delete memo.
- **Risks:** SwiftData lifecycle; avoid accessing memo after delete.

### Step 16: Lot descriptor – Dimensions and Color
- **Goal:** For Lot, include Dimensions and Color in StoneDescriptionBuilder.
- **Files:** `TransactionViewModel.swift` (StoneDescriptionBuilder)
- **Acceptance:** Lot line items show dimensions and color in description.
- **Tests:** Build; add lot stone to memo.
- **Risks:** Spec says "if lot – stone color" – already in top line for non-diamond; add dimensions for lot in same block.

### Step 17: Dimensions – exact decimals + mm
- **Goal:** No forced %.2f; use user-entered precision; append " mm".
- **Files:** `TransactionViewModel.swift` (StoneDescriptionBuilder), dimension formatting
- **Acceptance:** "1.5 × 2 × 3 mm" or "1.234 × 2.5 × 3 mm" per input.
- **Tests:** Build; verify descriptor.
- **Risks:** Parsing; avoid losing precision.
