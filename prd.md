# Project: QDI Gemstone ERP (MacOS Native)

## 10. Architecture & Refactor Goals (Current Focus)
- **Goal:** Consolidate logic and fix recurring crashes.
- **Unified Transaction Model:**
  - `Invoice` and `Memo` should share a common underlying structure (e.g., `Transaction` protocol) to avoid duplicate code.
  - `LineItem` must be a single, robust model that handles ALL 3 types (Inventory, Brokered, Service) via an Enum or clear optionals.
- **MVVM Strictness:**
  - **NO logic in Views.** All calculations (totals, tax, inventory updates) must move to `TransactionViewModel`.
  - Views should only display data.
- **SwiftData Cleanliness:**
  - Ensure relationships (Gemstone <-> LineItem) are optional and safe.
  - Fix any "Force Unwrapping" (using `!`) that causes crashes.

## 1. Project Overview
We are building a native MacOS application for "Quality Diajewels Inc." to manage gemstone inventory, memos, and invoicing. The app must be local-first, fast, and optimized for a desktop environment.

## 2. Tech Stack
- **Language:** Swift
- **UI Framework:** SwiftUI (MacOS target)
- **Database:** SwiftData (Local persistence) or SQLite
- **Architecture:** MVVM (Model-View-ViewModel)

## 3. Design System & Vibe
- **Theme:** "Budget-Pro" aesthetic. Clean, minimalist, professional.
- **Color Palette:**
  - Primary: Pastel Blue (Trust, calming)
  - Accent: Pastel Red (Urgency, alerts)
  - Background: White/Light Gray (High readability)
- **Typography:** San Francisco (System default), clean and readable numbers.
- **UI Refresh (QuickBooks-inspired):**
  - Dashboard: 2-column layout (left scrollable content, right fixed Info Panel).
  - Left: Header + search placeholder, function card grid (Add Stone, New Memo, New Invoice, Inventory, Memos, Invoices, Customers, Scanner), summary widgets (carats, value on memo, items on memo/available), Recent Activity.
  - Right Info Panel (280px): RFID status pill, Oldest Open Memos (top 5, click to show detail summary), Inventory Snapshot (available/on memo/sold), Quick Links (navigate to Inventory/Memos/Invoices).
  - Selection-driven: clicking memo rows updates info panel with memo detail summary.
  - Design tokens: AppSpacing (xs/s/m/l/xl), AppCornerRadius (s/m/l), AppCard container.

## 4. Key Features
### A. Inventory Management (The Core)
- **Data Points:** SKU, Stone Type (Diamond/Ruby/Sapphire), Carat Weight, Color, Clarity, Cut, Origin, Cost Price, Sell Price.
- **RFID Integration:**
  - Must interface with **Zebra ZD611R** for printing tags.
  - Must interface with **Kcosit Handheld Reader** for scanning.
  - *Note for AI:* Create an "RFIDService" protocol so we can mock this functionality until drivers are installed.
- **RFID Milestone 1: Reliable Detection** (implemented)
  - Connects to FTDI USB-Serial reader at `/dev/cu.usbserial*`, 115200 8N1.
  - Uses Silion framing: FF LEN CMD [DATA...] CRC_H CRC_L. CRC16-CCITT (poly 0x1021, init 0xFFFF).
  - Sends Start Async Inventory on connect; Stop Async Inventory on disconnect/app terminate.
  - Parses tag event frames (CMD 0xAA), validates CRC, emits TagScan with hex identifier.
  - Debounces duplicate events (300ms). Reconnects with backoff (2s up to 10s) on error/unplug.
  - Dashboard RFID Status panel: status, tagsDetectedCount, lastTagIdentifier, lastSeen, Reconnect.

### B. The Memo System (Critical Business Logic)
- **Concept:** Stones are often sent to customers on "Memo" (consignment) before being sold.
- **Status Workflow:**
  1. In Stock ->
  2. On Memo (assigned to Customer X) ->
  3. Sold (Invoice generated) OR Returned (Back to Stock).

### C. Dashboard
- Quick view of: Total Carats in Stock, Total Value on Memo, Recent Activity.

## 5. Constraints
- **No Web Apps:** This must run natively on MacOS.
- **Offline First:** The app must work without an internet connection (local database).
## 6. Logic & Data Updates (Phase 2)
- **Multi-Stone Memos:** A single Memo object must contain an *array* of Gemstones. It is not 1:1.
- **History Logging:**
  - Every Gemstone must have a related `[HistoryEvent]` list.
  - Events to track: "Date Added", "Sent to Customer X", "Returned from Customer X", "Sold".
  - This history must be viewable in a "Timeline" format on the Gemstone Detail view.
- **Customer Logic:**
  - Clicking a Customer shows their "Life Cycle": Items currently on memo, items bought, items returned.
- **Dashboard Navigation:**
  - The Dashboard must include large "Quick Action" buttons (e.g., "New Memo", "Add Stone") for fast entry.

  ## 7. Transaction Forms (Memo & Invoice)
- **UI Layout:** "Classic Invoice" style.
  - **Header:** Customer Picker, Date, Due Date, Terms (Net 30, etc.), Reference Number.
  - **Body (Line Items):** A dynamic list of rows.
  - **Footer:** Subtotal, Tax, Grand Total, Notes.
- **Line Item Logic:**
  - Users do NOT type product names manually.
  - Users click "Add Stone" -> Select from available Inventory -> Data (Carats, Price, Description) auto-fills.
  - Allow manual override of the "Sell Price" (Rate) for that specific transaction.
- **Data persistence:**
  - Creating an Invoice must mark the selected stones as "Sold" in the Inventory.
  - Creating a Memo must mark them as "On Memo".

  ## 8. Transaction Documents (Invoices & Memos)
- **Unified Logic:** "Invoices" and "Memos" are both *Transactions*. They share the same structure.
- **Line Item Flexibility (Hybrid System):**
  - Every row in a transaction must be able to be ONE of two types:
    1.  **Inventory Item:** Linked to a `Gemstone`. (Updates stock status). Fields: SKU, Description (Auto), Carats (Auto), Price (Editable).
    2.  **Custom Item:** No link. Free text. (e.g., "Shipping", "Sizing Fee"). Fields: Description (Manual), Price (Manual).
- **The Memo List View:**
  - The "Memos" tab must display a list of *Memo Documents* (grouped by Date/Customer), NOT a list of individual stones.
  - Clicking a Memo row opens the "Memo Detail View" (which looks like the Invoice View), showing all items on that memo.

  ## 9. Brokering & Manual Entry Updates
- **Line Item Types (Revised):**
  1.  **Inventory Stone:** Linked to existing Gemstone ID. (Read-only description/carats).
  2.  **Brokered/Manual Stone:** NO Gemstone ID. User manually types Description AND Carats. (Used for external stones).
  3.  **Service/Fee:** NO Gemstone ID. User types Description. Carats field is hidden or N/A.
- **Customer Management:**
  - Need a "Quick Add Customer" button directly inside the Invoice/Memo creation form (beside the customer picker).
  - Need a standard "Add Customer" sheet in the Customers tab.
- **Bug Fixes:**
  - **Memo List Display:** The Memos list currently shows blank rows for non-inventory items. It must handle nil Gemstone relationships gracefully by falling back to the `manualDescription`.

## Demo Data System

- **Reset Demo Data:** A button in the Dashboard right info panel (Quick Links section) allows users to wipe all existing SwiftData records and insert a fresh, realistic demo dataset (Style 1).
- **Confirmation:** Tapping "Reset Demo Data" shows an alert: "This will delete and recreate all demo data." User must confirm before reset.
- **Feedback:** On success, a transient green banner shows "Demo data reset successfully." On error, an error message is displayed.
- **Startup Seeding:** The app seeds demo data only when the database is empty or when the user explicitly taps "Reset Demo Data." It does not reseed on every launch.
- **Dataset (Style 1):**
  - 10 Customers (Boutique, Jeweler, Wholesaler)
  - 30 Gemstones: DIA001–010, RU001–010, SAP001–010 with realistic carat, color, clarity, cost/sell
  - 12 Memos: 6 open (on memo), 6 returned
  - 10 Invoices: 5 paid, 5 sent
  - History events for gemstones

### Change Log
- **2026-02-23:** Demo Data System: "Reset Demo Data" button in Dashboard info panel; `DemoDataManager` with `resetAllData` and `seedDemoData`; Style 1 dataset (10 customers, 30 gemstones, 12 memos, 10 invoices); confirmation alert and success toast.
- **2026-02-25:** RFID Milestone 1: Start/Stop Async Inventory commands, Silion frame parser with CRC16, RFID Status panel on Dashboard. Tags shown as raw hex until EPC parsing (Milestone 2).
- **2026-02-25:** UI Refresh (QuickBooks-inspired): 2-column Dashboard with function card grid, summary widgets, right Info Panel (RFID pill, Oldest Open Memos, Inventory Snapshot, Quick Links). Sidebar grouped into Get Started / Sales / Inventory. Design tokens (AppSpacing, AppCornerRadius, AppCard).

### RFID Next (Milestone 2)
- EPC extraction from tag event payload (parse EPC from binary frame).
- Database lookup: match scanned EPC to Gemstone in SwiftData.
- Routing: Create Gem / Add to Memo / Process Return based on context.

## 11. Customer Data Improvements
- **Fields:** Split "Name" into `firstName` and `lastName`.
- **Address Block:** Add `addressLine1`, `city`, `country`, `zipCode`.
- **UI:** The "Add Customer" sheet should be organized:
    - Section 1: Contact (First Name, Last Name, Company, Email, Phone)
    - Section 2: Address (Street, City, Zip, Country)

## 12. Intelligent Document Numbering (Memos & Invoices)
- **Auto-Increment:** When opening the "New Memo" screen, the system must automatically calculate the next available number.
    - Logic: `max(existingMemoNumbers) + 1`.
    - Default start: 1001 (if no memos exist).
- **Manual Override:** The "Memo Number" field must be editable.
- **Conflict Check:** If the user manually types a number that already exists, show a warning.

## 13. Inventory Status & Locking
- **Gemstone Statuses:**
  - `Available` (Live in safe)
  - `On Memo` (With a customer)
  - `Sold` (Invoiced and gone)
- **Selection Rules:**
  - The "Add Stone" picker in Invoices/Memos MUST filter the list.
  - Show ONLY stones where `status == .available`.
  - *Exception:* (Future feature) converting a Memo to an Invoice.
- **State Transitions:**
  - **Create Memo:** Changes selected stones from `Available` -> `On Memo`.
  - **Create Invoice:** Changes selected stones from `Available` -> `Sold`.
  - **Delete Memo:** (If a memo is deleted/returned) Changes stones back to `Available`.

## 14. Memo-to-Invoice Conversion (The "Settlement" Workflow)
- **Goal:** Allow users to select specific items from an Active Memo and convert them to an Invoice.
- **UI Workflow:**
  1.  Open Memo Detail View.
  2.  Click "Action" -> "Invoice Selected Items".
  3.  View enters "Selection Mode" (Checkboxes appear next to items).
  4.  User selects items and confirms.
  5.  System navigates to a **New Invoice Screen** pre-filled with:
      - The same Customer.
      - The selected items (Status: `Sold`).
      - The prices from the Memo (editable).
- **Data Logic (Crucial):**
  - **Source Memo:** The selected items must be REMOVED from the active list of the Memo (or marked as "Settled") so the Memo only shows what is *still* outstanding.
  - **Gemstone Status:** Update from `.onMemo` -> `.sold`.
  - **History Log:** Create a `HistoryEvent` for each stone: "Converted from Memo #[ID] to Invoice #[ID]".

## 15. Document Generation (PDF Engine)
- **Method:** HTML-to-PDF rendering (using `WKWebView` or `PDFKit`).
- **Template Style:** "Clean Professional."
    - **Header:** Company Logo (Top Left), Company Info (Top Right), Document Title (Big Font).
    - **Customer Block:** "Bill To" section with full address.
    - **Meta Data:** Invoice #, Date, Due Date, Terms.
    - **Table:** Columns for SKU, Description, Carats, Rate, Amount.
    - **Footer:** Subtotal, Tax, Grand Total, Payment Instructions, Signature Line.
- **Logo Handling:** The app must allow the user to pick a logo image, which is then Base64 encoded and embedded in the PDF.
- **Actions:**
    - "Print/Export" button on Invoice and Memo Detail views.
    - "Share" sheet to email the PDF directly.

    ## 16. Invoice Management Module
- **Sidebar:** Add a new "Invoices" tab to the main navigation.
- **List View:**
    - Group invoices by **Month** (e.g., "February 2026") or **Status**.
    - Row Columns: Invoice #, Customer, Date, Total Amount, Status (Unpaid/Paid).
    - **Visual Cues:**
        - "Unpaid" = Red/Orange text.
        - "Paid" = Green text.
- **Detail View:**
    - Clicking a row opens `InvoiceDetailView`.
    - Shows: Header info, Line Items (Inventory + Service), Totals.
    - **Actions:** Button to "Mark as Paid" (updates status).