# GEMAPP 13-Task Execution Queue

## 1. Needed Changes (Summary)

1. **Convert-to-invoice popup** – Stop conversion window from reopening after Esc/Cancel.
2. **Multiple stone selection** – Allow multi-select in Add from Inventory by default (no Cmd hold).
3. **Delete memo/invoice** – Auto-close window and remove from all lists.
4. **Manual SKU** – Honor user-edited SKU instead of always regenerating.
5. **Esc memo/invoice** – Prevent Esc from closing window without save prompt.
6. **Quick intake leave** – Don't prompt if form is autofilled and user made no changes.
7. **Convert to invoice** – Open invoice window prefilled instead of special conversion window.
8. **Table sort** – Sort ascending/descending on column double-click.
9. **Generate mock data** – Fix button label on dashboard right bar bottom.
10. **Dashboard memo click** – Clicking memo in oldest/recent list opens memo.
11. **Polish memo/invoice tab** – Modernize UI (less old-school accounting).
12. **On memo click** – Clicking "On Memo" on a stone opens the memo.
13. **Customer tab** – Fix Past purchases and On memo not populating when customer selected.

## 2. Implementation Approach

**Order:** Fix critical bugs first (1, 3, 13), then UX (2, 4, 5, 6), then flow changes (7), then polish (8–12).

**Patterns:** Follow existing SwiftUI patterns, `@State`, `NotificationCenter`, model context.

## 3. Execution Queue

| Step | Goal | Files | Acceptance |
|------|------|-------|------------|
| 1 | Fix convert-to-invoice popup reopening | MemosView, TransactionViewModel | Esc/Cancel dismisses; doesn't reopen |
| 2 | Multi-select by default in Add from Inventory | InventorySelectSheet | Can select multiple without Cmd |
| 3 | Delete memo/invoice auto-close and list refresh | MemosView, InvoiceDetailView, lists | Delete closes window; removed from lists |
| 4 | Honor manual SKU | StoneFormView, SKUGenerator/saveCurrent | Edited SKU persisted when valid |
| 5 | Block Esc closing without save | MemoWindowView, InvoiceWindowView | Esc triggers leave-without-saving flow |
| 6 | Quick intake: no leave prompt if no edits | StoneFormView, QuickIntakeView | Autofilled + no changes = no prompt |
| 7 | Convert: open invoice window prefilled | MemoDocumentView, TransactionViewModel | New Invoice window with prefilled data |
| 8 | Table sort on double-click | MemosView, InvoiceListView, CustomerDetailView, etc. | Double-click column toggles sort |
| 9 | Fix Generate mock data button | DashboardView | Button readable, correct position |
| 10 | Dashboard memo click opens memo | DashboardView | Oldest/recent memo row opens memo window |
| 11 | Polish memo/invoice tab | MemosView, InvoiceListView | Modernized look |
| 12 | On memo click opens memo | InventoryListView or stone detail | "On Memo" link/button opens memo |
| 13 | Customer Past purchases / On memo | Customer model, CustomerDetailView | Data populates when customer selected |
