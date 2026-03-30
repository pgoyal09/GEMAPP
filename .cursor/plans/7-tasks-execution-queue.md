# Execution Queue: 7 Tasks (Autonomous Stepwise)

## 1. Needed Changes

1. **Exit prompt wording** – Change "Discard" button label to "Discard edits and leave" in all leave-without-saving alerts (memo, invoice, window-level, app shell, stone form).
2. **Save and Close** – Confirm existing behavior: Save and Close saves then closes memo/invoice (no code change if already correct).
3. **Diamond Lot UX** – When grouping = Lot and stone type = Diamond: empty and disable cut, polish, symmetry, fluorescence, cert, all dimensions, treatment; add "Size" text field. Persist size on Gemstone (new optional property).
4. **Stone Type column** – Add a "Stone Type" column to memo line items table and invoice line items table (from gemstone.stoneType or "—"/"Service").
5. **Diamond lot description** – Auto-fill description for diamond lots as [color] [size] [clarity] (use new size field).
6. **Single/pair diamond description** – Ensure format: [stone type] [Carat] [Color] [clarity] ([cut][polish][symmetry])-[Fluorescence] newline [Cert Lab] [Cert No] when certified.
7. **Open / Closed Memos** – Rename "Memos" to "Open Memos"; add "Closed Memos" tab. Open = memos with open items (e.g. status .onMemo or hasOpenItems); Closed = memos that are closed (isClosed). When memo closes it appears in Closed. In Closed Memos table remove "Days Old" column.

## 2. Implementation Approach

- **Order**: 1 → 2 (prompts and verify) → 3 (model + form for Lot) → 4 (columns) → 5 → 6 (descriptions) → 7 (tabs).
- **Step 1**: Replace button title "Discard" with "Discard edits and leave" in every alert that offers it.
- **Step 2**: Read existing saveAndClose/onSaveAndClose paths; no change unless bug found.
- **Step 3**: Add `var size: String?` to Gemstone; in StoneFormView when diamond && grouping == .lot, clear/disable the listed fields and show Size field; on load/save handle size.
- **Step 4**: Add Stone Type column to MemosView (MemoDocumentView) line items header and row; add to InvoiceDetailView line items header and EditableLineItemRow (or new column in table).
- **Step 5**: In StoneDescriptionBuilder buildDiamondDescription for lot, use [color] [size] [clarity]; size from stone.size.
- **Step 6**: Verify/adjust single/pair format to match spec exactly.
- **Step 7**: MemosViewModel: add openMemos and closedMemos (or filter in view). MemosView: segmented control or Picker "Open Memos" | "Closed Memos"; two table variants; Closed table without Days Old column.

## 3. Execution Queue

| Step | Title | Goal | Files | Acceptance | Tests | Risks |
|------|--------|------|-------|------------|--------|--------|
| 1 | Discard edits and leave | Use that label in all exit prompts | MemosView, InvoiceDetailView, MemoWindowView, InvoiceWindowView, AppShellView, StoneFormView | Every prompt shows "Discard edits and leave" | Build | None |
| 2 | Save and Close behavior | Confirm save then exit | (verification only) | No regression | Build | None |
| 3 | Diamond Lot fields + Size | Lot diamonds: disable listed fields, add Size | Gemstone.swift, StoneFormView.swift | Size field; others empty/disabled for lot | Build | Schema |
| 4 | Stone Type column | Column in memo and invoice line items | MemosView (MemoDocumentView), InvoiceDetailView, EditableLineItemRow/LineItemColumnLayout | Column visible, shows type or — | Build | Layout |
| 5 | Lot description | [color] [size] [clarity] for diamond lot | TransactionViewModel (StoneDescriptionBuilder) | Description matches | Build | None |
| 6 | Single/pair description | Exact format with cert on newline | TransactionViewModel | Matches spec | Build | None |
| 7 | Open / Closed Memos tabs | Tabs, closed no Days old | MemosViewModel, MemosView | Two tabs; closed list no Days old | Build | Filter logic |
