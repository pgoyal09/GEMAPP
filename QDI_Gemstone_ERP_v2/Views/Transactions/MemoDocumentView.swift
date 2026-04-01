import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

struct MemoDocumentView: View {
    @Bindable var memo: Memo
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    @Environment(\.documentDirtyTracker) private var dirtyTracker
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Customer.lastName) private var allCustomers: [Customer]

    @State private var selectedItemIDs: Set<PersistentIdentifier> = []
    @State private var showInventorySheet = false
    @State private var showLotSheet = false
    @State private var showAddCustomerSheet = false
    @State private var showDeleteConfirm = false
    @State private var customerSearchText = ""
    @State private var hasUnsavedEdits = false
    @State private var isSaving = false
    @State private var isGeneratingPDF = false
    @State private var toastMessage: String?
    @State private var toastIsError = false
    @State private var totalRefreshID = UUID()
    @State private var showUnsavedAlert = false
    @State private var duplicateWarning: String?
    @State private var showCustomerDropdown = false
    @State private var dateText = ""
    @State private var dateError: String?
    @State private var selectedItemType: LineItemKind?
    @AccessibilityFocusState private var isHeaderFocused: Bool

    @AppStorage("requireSalespersonOnMemos") private var requireSalesperson: Bool = true

    private var filteredCustomers: [Customer] {
        let q = customerSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return allCustomers }
        return allCustomers.filter { $0.displayName.lowercased().contains(q) }
    }

    /// The best inline autocomplete match (first filtered customer).
    private var inlineSuggestion: String? {
        let q = customerSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, memo.customer == nil else { return nil }
        if let match = filteredCustomers.first,
           match.displayName.lowercased().hasPrefix(q.lowercased()) {
            return match.displayName
        }
        return nil
    }

    /// Sum of open memo values for the selected customer, excluding current memo.
    private var customerOpenMemoValue: Decimal {
        guard let customer = memo.customer else { return 0 }
        let currentID = memo.persistentModelID
        let descriptor = FetchDescriptor<Memo>()
        let allMemos = (try? modelContext.fetch(descriptor)) ?? []
        return allMemos
            .filter { $0.customer?.persistentModelID == customer.persistentModelID && $0.persistentModelID != currentID && $0.status == .onMemo }
            .reduce(Decimal.zero) { $0 + $1.openMemoAmount }
    }

    private var isNewMemo: Bool {
        memo.lineItems.isEmpty && memo.createdAt.timeIntervalSinceNow > -60
    }

    var body: some View {
        Group {
            if memo.isDeleted {
                Text("Memo no longer available")
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.inkMuted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: AppSpacing.hero) {
                            headerSection
                            lineItemsSection
                            totalsSection
                            notesSection
                        }
                        .padding(AppSpacing.hero)
                    }
                    bottomToolbar
                }
            }
        }
        .accessibilityIdentifier("MemoDocumentView")
        .onAppear { isHeaderFocused = true }
        .id(totalRefreshID)
        .onChange(of: memo.lineItems.count) { _, _ in totalRefreshID = UUID() }
        .sheet(isPresented: $showInventorySheet) {
            InventorySelectSheet { stones in
                var zeroPriceSkus: [String] = []
                var duplicateMessages: [String] = []
                for stone in stones {
                    do {
                        try TransactionService.addStone(stone, to: memo, modelContext: modelContext)
                        if stone.sellPrice == 0 { zeroPriceSkus.append(stone.sku) }
                    } catch let error as TransactionError {
                        switch error {
                        case .stoneAlreadyOnMemo, .duplicateStone:
                            duplicateMessages.append(error.localizedDescription)
                        default:
                            showToast("Failed to add stone: \(error.localizedDescription)", isError: true)
                        }
                    } catch {
                        showToast("Failed to add stone: \(ErrorMapper.userMessage(from: error))", isError: true)
                    }
                }
                if !duplicateMessages.isEmpty {
                    duplicateWarning = duplicateMessages.joined(separator: "\n")
                }
                if !zeroPriceSkus.isEmpty {
                    showToast("Zero price: \(zeroPriceSkus.joined(separator: ", "))", isError: false)
                }
                markDirty()
            }
        }
        .alert("Duplicate Stone Warning", isPresented: .constant(duplicateWarning != nil)) {
            Button("OK") { duplicateWarning = nil }
        } message: {
            Text(duplicateWarning ?? "")
        }
        .sheet(isPresented: $showLotSheet) {
            LotSelectSheet { lot, carats in
                do {
                    try LotService.addToMemo(lot, carats: carats, memo: memo, modelContext: modelContext)
                } catch {
                    showToast("Failed to add lot: \(ErrorMapper.userMessage(from: error))", isError: true)
                }
                markDirty()
            }
        }
        .sheet(isPresented: $showAddCustomerSheet) {
            CustomerFormSheet(mode: .add) { customer in
                memo.customer = customer
                customerSearchText = customer.displayName
                markDirty()
            }
        }
        .alert("Delete Memo?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                do {
                    try MemoService.deleteMemo(memo, modelContext: modelContext)
                    dismiss()
                } catch {
                    showToast("Failed to delete memo: \(ErrorMapper.userMessage(from: error))", isError: true)
                }
            }
        } message: {
            Text("This will return all items and permanently delete the memo.")
        }
        .interactiveDismissDisabled(isSaving)
        .overlay {
            if let msg = toastMessage {
                ToastOverlay(message: msg, isError: toastIsError)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation(reduceMotion ? nil : .default) { toastMessage = nil }
                        }
                    }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        GlassCard(padding: AppSpacing.hero) {
            VStack(alignment: .leading, spacing: AppSpacing.section) {
                HStack {
                    Text("Memo #\(memo.referenceNumber)")
                        .font(AppTypography.heading)
                        .foregroundStyle(AppColors.ink)
                        .accessibilityFocused($isHeaderFocused)
                    Spacer()
                    // Only show status badge on existing memos
                    if !isNewMemo {
                        memoStatusBadge
                    }
                }

                // Current Open Memo Value for selected customer
                if memo.customer != nil {
                    let openValue = customerOpenMemoValue
                    if openValue > 0 {
                        HStack(spacing: AppSpacing.standard) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .foregroundStyle(AppColors.primary)
                            Text("Current Open Memo Value: \(openValue.asCurrency)")
                                .font(AppTypography.subheading)
                                .foregroundStyle(AppColors.ink)
                        }
                        .padding(AppSpacing.comfortable)
                        .background(
                            RoundedRectangle(cornerRadius: AppCornerRadius.small, style: .continuous)
                                .fill(AppColors.primary.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppCornerRadius.small, style: .continuous)
                                        .strokeBorder(AppColors.primary.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                }

                HStack(spacing: AppSpacing.hero) {
                    // Customer autocomplete
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Customer").font(AppTypography.caption).foregroundStyle(AppColors.inkSubtle)
                        ZStack(alignment: .topLeading) {
                            VStack(spacing: AppSpacing.compact) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 0) {
                                        TextField("Search customers...", text: $customerSearchText)
                                            .textFieldStyle(.plain)
                                            .font(AppTypography.smallValue)
                                            .foregroundStyle(AppColors.ink)
                                            .glassField()
                                            .overlay(alignment: .trailing) {
                                                if memo.customer != nil {
                                                    Button {
                                                        memo.customer = nil
                                                        customerSearchText = ""
                                                        markDirty()
                                                    } label: {
                                                        Image(systemName: "xmark.circle.fill")
                                                            .foregroundStyle(AppColors.inkSubtle)
                                                            .font(AppTypography.caption)
                                                    }
                                                    .buttonStyle(.plain)
                                                    .padding(.trailing, AppSpacing.standard)
                                                }
                                            }
                                            .onChange(of: customerSearchText) { _, newVal in
                                                let trimmed = newVal.trimmingCharacters(in: .whitespacesAndNewlines)
                                                if let c = memo.customer, trimmed != c.displayName {
                                                    memo.customer = nil
                                                    markDirty()
                                                }
                                                showCustomerDropdown = !trimmed.isEmpty && memo.customer == nil
                                            }
                                            .onKeyPress(.tab) {
                                                if let match = filteredCustomers.first, memo.customer == nil {
                                                    memo.customer = match
                                                    customerSearchText = match.displayName
                                                    showCustomerDropdown = false
                                                    markDirty()
                                                    return .handled
                                                }
                                                return .ignored
                                            }
                                        // Inline hint: Tab to complete
                                        if let suggestion = inlineSuggestion {
                                            Text("⇥ \(suggestion)")
                                                .font(AppTypography.caption)
                                                .foregroundStyle(AppColors.inkSubtle.opacity(0.6))
                                                .padding(.leading, AppSpacing.compact)
                                                .padding(.top, 2)
                                        }
                                    }
                                    .frame(width: 200)
                                    Button(action: { showAddCustomerSheet = true }) {
                                        Image(systemName: "plus.circle").foregroundStyle(AppColors.primary)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Add Customer")
                                }
                            }
                            if showCustomerDropdown && !filteredCustomers.isEmpty {
                                ScrollView {
                                    VStack(alignment: .leading, spacing: 0) {
                                        ForEach(filteredCustomers) { c in
                                            Button {
                                                memo.customer = c
                                                customerSearchText = c.displayName
                                                showCustomerDropdown = false
                                                markDirty()
                                            } label: {
                                                Text(c.displayName)
                                                    .font(AppTypography.smallValue)
                                                    .foregroundStyle(AppColors.ink)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                    .padding(.horizontal, AppSpacing.standard)
                                                    .padding(.vertical, AppSpacing.compact)
                                            }
                                            .buttonStyle(.plain)
                                            .background(Color.white.opacity(0.05))
                                        }
                                    }
                                }
                                .frame(minWidth: 200, maxWidth: 200, maxHeight: 150)
                                .background(AppColors.panelBackground)
                                .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.small))
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppCornerRadius.small)
                                        .strokeBorder(AppColors.cardStroke, lineWidth: 1)
                                )
                                .shadow(radius: 8)
                                .offset(y: 32)
                                .zIndex(10)
                            }
                        }
                    }

                    // Date entry with manual typing + calendar icon
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Date").font(AppTypography.caption).foregroundStyle(AppColors.inkSubtle)
                        TextField("MM/DD/YYYY", text: $dateText)
                            .glassField()
                            .frame(width: 140)
                            .onSubmit { parseDateText() }
                            .onChange(of: dateText) { _, _ in dateError = nil }
                            .overlay(alignment: .trailing) {
                                DatePicker("", selection: Binding(
                                    get: { memo.dateAssigned ?? Date() },
                                    set: { newDate in
                                        memo.dateAssigned = newDate
                                        syncDateText(from: newDate)
                                        markDirty()
                                    }
                                ), displayedComponents: .date)
                                .labelsHidden()
                                .frame(width: 20)
                                .opacity(0.02)
                                .overlay {
                                    Image(systemName: "calendar")
                                        .foregroundStyle(AppColors.primary)
                                        .font(AppTypography.caption)
                                        .allowsHitTesting(false)
                                }
                                .padding(.trailing, AppSpacing.standard)
                            }
                        if let error = dateError {
                            Text(error)
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.danger)
                        }
                    }

                    // Salesperson (conditionally shown)
                    if requireSalesperson {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Salesperson").font(AppTypography.caption).foregroundStyle(AppColors.inkSubtle)
                            TextField("Salesperson name", text: Binding(
                                get: { memo.salesperson ?? "" },
                                set: { memo.salesperson = $0.isEmpty ? nil : $0; markDirty() }
                            ))
                            .glassField()
                            .frame(width: 160)
                        }
                    }
                }
            }
        }
        .onAppear {
            syncDateText(from: memo.dateAssigned ?? Date())
            if let c = memo.customer {
                customerSearchText = c.displayName
            }
        }
    }

    private func syncDateText(from date: Date) {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy"
        dateText = formatter.string(from: date)
    }

    private func parseDateText() {
        let trimmed = dateText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy"

        // Try full format first
        if let date = formatter.date(from: trimmed) {
            memo.dateAssigned = date
            syncDateText(from: date)
            dateError = nil
            markDirty()
            return
        }

        // Try MM/DD without year — autofill current year
        let shortFormatter = DateFormatter()
        shortFormatter.dateFormat = "MM/dd"
        if let partial = shortFormatter.date(from: trimmed) {
            let year = Calendar.current.component(.year, from: Date())
            var components = Calendar.current.dateComponents([.month, .day], from: partial)
            components.year = year
            if let date = Calendar.current.date(from: components) {
                memo.dateAssigned = date
                syncDateText(from: date)
                dateError = nil
                markDirty()
                return
            }
        }

        dateError = "Invalid date. Use MM/DD/YYYY"
    }

    @ViewBuilder
    private var memoStatusBadge: some View {
        if memo.isDeleted {
            EmptyView()
        } else {
            let tone: StatusBadge.Tone = switch memo.status {
            case .onMemo: .accent
            case .returned: .warning
            case .sold: .success
            }
            StatusBadge(title: memo.status.rawValue, tone: tone)
        }
    }

    // MARK: - Line Items

    private var lineItemsSection: some View {
        GlassCard(padding: AppSpacing.section) {
            VStack(alignment: .leading, spacing: AppSpacing.comfortable) {
                HStack {
                    SectionHeader(title: "Line Items")
                    Spacer()
                    addItemsMenu
                }

                if !selectedItemIDs.isEmpty {
                    selectedItemActions
                }

                // Header row
                HStack(spacing: 0) {
                    Toggle("", isOn: .constant(false)).frame(width: 24).hidden()
                    TableHeader(title: "SKU", width: TableColumn.sku)
                    TableHeader(title: "Type", width: TableColumn.type)
                    TableHeader(title: "Description", width: TableColumn.description)
                    TableHeader(title: "Carats", width: TableColumn.carat)
                    TableHeader(title: "Rate", width: TableColumn.price)
                    TableHeader(title: "Amount", width: TableColumn.price)
                }
                .padding(.horizontal, AppSpacing.comfortable)

                ForEach(memo.lineItems) { item in
                    HStack(spacing: 0) {
                        Toggle("", isOn: Binding(
                            get: { selectedItemIDs.contains(item.persistentModelID) },
                            set: { if $0 { selectedItemIDs.insert(item.persistentModelID) } else { selectedItemIDs.remove(item.persistentModelID) } }
                        ))
                        .frame(width: 24)

                        EditableLineItemRow(item: item) { markDirty() }
                    }
                    .padding(.horizontal, AppSpacing.comfortable)
                    .padding(.vertical, 2)
                    .contextMenu {
                        Button("Remove") {
                            do {
                                try TransactionService.removeLineItem(item, modelContext: modelContext)
                                markDirty()
                            } catch {
                                showToast("Failed to remove item: \(ErrorMapper.userMessage(from: error))", isError: true)
                            }
                        }
                    }
                }

                if memo.lineItems.isEmpty {
                    Text("No line items. Add stones or services above.")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.inkSubtle)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.hero)
                }
            }
        }
    }

    private var addItemsMenu: some View {
        HStack(spacing: 2) {
            itemTypeButton(label: "Single/Pair", kind: .inventory) { showInventorySheet = true }
            itemTypeButton(label: "Lot", kind: nil) { showLotSheet = true }
                .help("A group of similar stones sold by total carat weight")
            itemTypeButton(label: "Brokered", kind: .brokered) {
                do {
                    try TransactionService.addBrokeredLine(to: memo, modelContext: modelContext)
                    markDirty()
                } catch {
                    showToast("Failed to add brokered line: \(ErrorMapper.userMessage(from: error))", isError: true)
                }
            }
            itemTypeButton(label: "Service", kind: .service) {
                do {
                    try TransactionService.addServiceLine(to: memo, modelContext: modelContext)
                    markDirty()
                } catch {
                    showToast("Failed to add service line: \(ErrorMapper.userMessage(from: error))", isError: true)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.small, style: .continuous)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCornerRadius.small, style: .continuous)
                        .strokeBorder(AppColors.cardStroke, lineWidth: 1)
                )
        )
    }

    private func itemTypeButton(label: String, kind: LineItemKind?, action: @escaping () -> Void) -> some View {
        let isSelected = selectedItemType == kind
        return Button {
            selectedItemType = kind
            action()
        } label: {
            Text(label)
                .font(AppTypography.caption)
                .fontWeight(.medium)
                .foregroundStyle(isSelected ? Color.white : AppColors.primary)
                .padding(.horizontal, AppSpacing.comfortable)
                .padding(.vertical, AppSpacing.standard)
                .background(
                    RoundedRectangle(cornerRadius: AppCornerRadius.small - 1, style: .continuous)
                        .fill(isSelected ? AppColors.primary : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    private var selectedItemActions: some View {
        HStack(spacing: 12) {
            Text("\(selectedItemIDs.count) selected")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.inkSubtle)
            Button("Return Items") {
                let items = memo.lineItems.filter { selectedItemIDs.contains($0.persistentModelID) && $0.status == .open }
                do {
                    try MemoService.returnItems(items, modelContext: modelContext)
                } catch {
                    showToast("Failed to return items: \(ErrorMapper.userMessage(from: error))", isError: true)
                }
                selectedItemIDs.removeAll()
                markDirty()
            }
            .buttonStyle(.outline(.init(AppColors.warning)))
            .help("Mark selected items as returned to inventory")
            Button("Convert to Invoice") {
                let items = memo.lineItems.filter { selectedItemIDs.contains($0.persistentModelID) && $0.status == .open }
                do {
                    if let invoice = try MemoService.convertToInvoice(memo: memo, selectedItems: items, modelContext: modelContext) {
                        openWindow(id: "invoice", value: invoice.persistentModelID)
                    }
                } catch {
                    showToast("Failed to convert to invoice: \(ErrorMapper.userMessage(from: error))", isError: true)
                }
                selectedItemIDs.removeAll()
            }
            .buttonStyle(.gradient)
            .help("Creates a new invoice from selected memo items")
        }
        .padding(.vertical, AppSpacing.standard)
    }

    @ViewBuilder
    private func lineItemStatusBadge(_ item: LineItem) -> some View {
        if item.status != .open {
            let tone: StatusBadge.Tone = switch item.status {
            case .open: .neutral
            case .returned: .warning
            case .sold: .success
            }
            StatusBadge(title: item.status.rawValue, tone: tone)
        }
    }

    // MARK: - Totals

    private var totalsSection: some View {
        GlassCard(padding: AppSpacing.section) {
            HStack {
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Total: \(memo.totalAmount.asCurrency)")
                        .font(AppTypography.heading)
                        .foregroundStyle(AppColors.ink)
                    Text("Open: \(memo.openMemoAmount.asCurrency)")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.primary)
                }
            }
        }
    }

    // MARK: - Notes

    private var notesSection: some View {
        GlassCard(padding: AppSpacing.section) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Notes").font(AppTypography.caption).foregroundStyle(AppColors.inkSubtle)
                TextEditor(text: $memo.notes)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.ink)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 60)
                    .onChange(of: memo.notes) { _, _ in markDirty() }
            }
        }
    }

    // MARK: - Bottom Toolbar

    private var bottomToolbar: some View {
        HStack {
            Button("Delete Memo") { showDeleteConfirm = true }
                .foregroundStyle(AppColors.danger)
                .buttonStyle(.plain)
            Spacer()
            Button("Export PDF") { exportPDF() }
                .buttonStyle(.outline)
                .disabled(isGeneratingPDF)
                .keyboardShortcut("p", modifiers: .command)
                .help("Generate a PDF document for printing or emailing")
            Button("Email PDF") { emailMemoPDF() }
                .buttonStyle(.outline)
                .disabled(isGeneratingPDF)
                .help("Generate PDF and open email compose with attachment")
            Button("Cancel") {
                if hasUnsavedEdits {
                    showUnsavedAlert = true
                } else {
                    NSApp.keyWindow?.close()
                }
            }
            .buttonStyle(.outline)
            .disabled(isSaving)
            Button("Save") {
                guard !isSaving else { return }
                isSaving = true
                defer { isSaving = false }
                saveMemo()
            }
            .buttonStyle(.gradient)
            .disabled(isSaving)
            .keyboardShortcut("s", modifiers: .command)
        }
        .padding(AppSpacing.section)
        .background(AppColors.panelBackground)
        .overlay(alignment: .top) { Divider().background(AppColors.cardElevated) }
        .alert("Unsaved Changes", isPresented: $showUnsavedAlert) {
            Button("Keep Editing", role: .cancel) {}
            Button("Discard", role: .destructive) {
                hasUnsavedEdits = false
                NSApp.keyWindow?.close()
            }
        } message: {
            Text("You have unsaved changes. Discard them?")
        }
    }

    private func saveMemo() {
        do {
            try modelContext.save()
            hasUnsavedEdits = false
            dirtyTracker.clearDirty()
            NotificationCenter.default.post(name: .memoOrInvoiceDidSave, object: nil)
            NotificationCenter.default.post(name: .dataStoreDidChange, object: nil)
        } catch {
            showToast("Failed to save memo: \(ErrorMapper.userMessage(from: error))", isError: true)
        }
    }

    private func exportPDF() {
        isGeneratingPDF = true
        PDFService.shared.generatePDF(memo: memo) { result in
            DispatchQueue.main.async {
                isGeneratingPDF = false
                switch result {
                case .success(let tempURL):
                    let panel = NSSavePanel()
                    panel.allowedContentTypes = [.pdf]
                    panel.nameFieldStringValue = "Memo-\(memo.referenceNumber).pdf"
                    panel.begin { response in
                        if response == .OK, let destURL = panel.url {
                            do {
                                if FileManager.default.fileExists(atPath: destURL.path) {
                                    try FileManager.default.removeItem(at: destURL)
                                }
                                try FileManager.default.copyItem(at: tempURL, to: destURL)
                            } catch {
                                showToast("Failed to save PDF: \(ErrorMapper.userMessage(from: error))", isError: true)
                            }
                        }
                        PDFService.shared.cleanupTempFile(at: tempURL)
                    }
                case .failure(let error):
                    showToast("PDF generation failed: \(ErrorMapper.userMessage(from: error))", isError: true)
                }
            }
        }
    }

    private func emailMemoPDF() {
        isGeneratingPDF = true
        PDFService.shared.generatePDF(memo: memo) { result in
            DispatchQueue.main.async {
                isGeneratingPDF = false
                switch result {
                case .success(let tempURL):
                    let service = NSSharingService(named: .composeEmail)
                    if let service = service {
                        service.recipients = [memo.customer?.email].compactMap { $0?.isEmpty == false ? $0 : nil }
                        service.subject = "Memo \(memo.referenceNumber)"
                        service.perform(withItems: [tempURL])
                    } else {
                        let picker = NSSharingServicePicker(items: [tempURL])
                        if let window = NSApp.keyWindow, let contentView = window.contentView {
                            picker.show(relativeTo: .zero, of: contentView, preferredEdge: .minY)
                        }
                    }
                    // Cleanup temp file after a delay to allow sharing service to finish
                    DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
                        PDFService.shared.cleanupTempFile(at: tempURL)
                    }
                case .failure(let error):
                    showToast("PDF generation failed: \(ErrorMapper.userMessage(from: error))", isError: true)
                }
            }
        }
    }

    private func markDirty() {
        hasUnsavedEdits = true
        dirtyTracker.markDirty()
    }

    private func showToast(_ message: String, isError: Bool = false) {
        toastIsError = isError
        withAnimation(reduceMotion ? nil : .default) { toastMessage = message }
    }
}
