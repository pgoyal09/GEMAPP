# Execution Queue: 12 Tasks (Autonomous Stepwise)

## 1. Needed Changes

1. **Convert to invoice** – When converting memo to invoice, create invoice and line item copies but do not mark stones/memo items as sold or save. On invoice save, mark originals as sold and persist.
2. **Automatic invoice numbering** – Add/fix `generateNextInvoiceNumber` and assign when creating new invoices (including from conversion).
3. **Exit prompt** – Add "Save and Close" button to leave-without-saving alerts (Memo, Invoice, and window-level Esc).
4. **Invoice description dirty** – Ensure editing the description field in invoice line items sets dirty state (e.g. EditableLineItemRow notifies on description change).
5. **Certificate image button** – Fix Choose button in stone editor (fileImporter binding or presentation).
6. **Stone detail bar** – Under first card when stone is on memo, add line "On Memo To [Customer]".
7. **Stone history "Memo to"** – Fix display when message or customer is missing.
8. **Customer history** – Ensure past memos and past invoices sections show items (fix fetch/relationship so On Memo and Past Purchases populate).
9. **Sold inventory** – Right-click context menu "View Invoice" that opens the invoice the stone is sold on.
10. **Accounting tab** – New tab: total profits, sales by month, aged receivables, sales by stone type, etc.; for internal tracking (QuickBooks for actual accounting).
11. **Card sizing** – Uniform card widths in the right bar of both inventory tabs (current vs sold).
12. **Diamond descriptor** – Auto-populate descriptor per spec: lot vs single/pair formats; [type][color][carat][clarity], cut/polish/symmetry, fluorescence, cert lab/number.

## 2. Implementation Approach

- **Order**: 1→2 (convert + numbering) then 3–4 (prompts/dirty), then 5–9 (UI fixes), then 10 (accounting – larger), then 11–12 (polish).
- **Convert (1)**: Add optional `originLineItem` on LineItem; convert creates invoice + copies with `originLineItem` set, no save; on InvoiceDetailView save, call helper to mark originLineItem and gemstones sold, then save.
- **Invoice number (2)**: Add `generateNextInvoiceNumber` in TransactionViewModel; use when creating new Invoice (conversion and any other creation path).
- **Prompts (3)**: Add third button "Save and Close" that saves then closes in Memo/Invoice leave alerts and InvoiceWindowView/MemoWindowView Esc handler.
- **Description dirty (4)**: In EditableLineItemRow when `persistOnEdit == false`, call `onUpdate?()` on description text change (e.g. `.onChange(of: descriptionText)`), guarded so sync doesn’t trigger it.
- **Certificate (5)**: Verify fileImporter is attached to correct parent; use `.fileImporter(isPresented:...)` on a view that’s in the hierarchy when sheet/window is visible.
- **On Memo To (6)**: In GemstoneDetailView under headerCard, if on memo and stone.memo != nil, add a line with customer name.
- **History (7)**: Inspect HistoryEvent usage; ensure "On memo to X" message is set and displayed safely when customer or memo is nil.
- **Customer history (8)**: Debug why fetchedActiveMemos/fetchedInvoices or onMemoRows/pastPurchaseRows are empty; fix relationship or fetch so data appears.
- **View Invoice (9)**: In sold inventory table context menu, add "View Invoice" that resolves invoice from selected stone’s line item and opens window.
- **Accounting (10)**: New NavigationItem, view, and view model; queries for invoices/line items; sections: profits, sales by month, aged receivables, sales by item type; optional exports.
- **Cards (11)**: Right bar uses InspectorWidth.ideal; ensure all cards in GemstoneDetailView (and any list) use consistent width (e.g. `.frame(maxWidth: .infinity)` or fixed width).
- **Diamond descriptor (12)**: Implement StoneDescriptionBuilder diamond rules: lot = [type][color][carat][clarity]; single/pair = [type][Carat][Color][clarity]([cut][polish][symmetry])-[Fluorescence] newline [Cert Lab] [Cert No].

## 3. Execution Queue

| Step | Title | Goal | Files | Acceptance | Tests | Risks |
|------|--------|------|-------|------------|--------|--------|
| 1 | Defer sold state on convert | Don’t mark stones/memo items sold on convert; mark only on invoice save | TransactionViewModel, LineItem, InvoiceDetailView | Convert creates draft invoice; save marks originals sold | Build, run convert then cancel → stones still on memo | LineItem schema change |
| 2 | Automatic invoice number | Next invoice number assigned on create | TransactionViewModel, convert + any Invoice() call sites | New invoices get sequential ref | Build, create invoice and check ref | None |
| 3 | Save and Close in prompt | Add button to leave-without-saving | MemosView, InvoiceDetailView, MemoWindowView, InvoiceWindowView | Three options: Keep Editing, Save and Close, Discard | Build | None |
| 4 | Description field dirty | Editing line description sets invoice dirty | EditableLineItemRow, InvoiceDetailView | Change description, Esc → prompt | Build | Avoid feedback loop with sync |
| 5 | Certificate Choose button | Fix file picker for cert image | StoneFormView | Choose opens picker and path updates | Build, test in editor | fileImporter placement |
| 6 | On Memo To customer line | Show "On Memo To [Customer]" in detail bar | GemstoneDetailView | Line visible when stone on memo | Build | None |
| 7 | Stone history Memo to | Fix broken "Memo to" in history | HistoryLogger / GemstoneDetailView / HistoryEvent | No break when customer nil | Build | None |
| 8 | Customer history items | Past memos/invoices show rows | CustomerDetailView, model | Selecting customer shows On Memo & Past Purchases | Build | Fetch/relationship |
| 9 | Sold inventory View Invoice | Context menu opens invoice | InventoryListView | Right-click sold stone → View Invoice opens invoice | Build | Resolve invoice from stone |
| 10 | Accounting tab | New tab with profits, sales by month, aged receivables, by type | New view + ViewModel, AppShellView, NavigationItem | Tab visible and sections show data | Build | Scope to internal tracking |
| 11 | Card sizing right bar | Uniform card width in inventory detail | GemstoneDetailView, DesignTokens/InspectorWidth | All cards same width in right bar | Build | Layout |
| 12 | Diamond descriptor | Auto descriptor per spec | TransactionViewModel (StoneDescriptionBuilder) | Lot and single/pair formats | Build | Field availability |
