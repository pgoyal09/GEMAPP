import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

struct MemoDocumentView: View {
    @Bindable var memo: Memo
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openDocumentTracker) private var openDocTracker
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
    @State private var isConverting = false
    @State private var toastMessage: String?
    @State private var toastIsError = false
    @State private var totalRefreshID = UUID()
    @State private var showUnsavedAlert = false
    @State private var duplicateWarning: String?
    @State private var showCustomerDropdown = false
    @State private var dateText = ""
    @State private var dateError: String?
    @State private var showDatePicker = false

    @AppStorage("requireSalespersonOnMemos") private var requireSalesperson: Bool = true

    private var filteredCustomers: [Customer] {
        let q = customerSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return allCustomers }
        return allCustomers.filter { $0.displayName.lowercased().contains(q) }
    }

    private var inlineSuggestion: String? {
        let q = customerSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, memo.customer == nil else { return nil }
        if let match = filteredCustomers.first,
           match.displayName.lowercased().hasPrefix(q.lowercased()) {
            return match.displayName
        }
        return nil
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
                        VStack(spacing: AppSpacing.hero) {
                            headerSection
                            lineItemsSection
                            totalsSection
                            notesSection
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(AppSpacing.hero)
                    }
                    bottomToolbar
                }
                .onKeyPress(.escape) {
                    handleCancel()
                    return .handled
                }
            }
        }
        .accessibilityIdentifier("MemoDocumentView")
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
        VStack(alignment: .leading, spacing: AppSpacing.section) {
            // Title row
            HStack {
                Text("Memo #\(memo.referenceNumber)")
                    .font(AppTypography.heading)
                    .foregroundStyle(AppColors.ink)
                Spacer()
                if !isNewMemo {
                    memoStatusBadge
                }
            }

            // Fields row (horizontal)
            HStack(spacing: AppSpacing.hero) {
                // Customer autocomplete
                customerField

                // Date field
                dateField

                // Salesperson
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
        .padding(AppSpacing.hero)
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                        .strokeBorder(AppColors.cardStroke, lineWidth: 1)
                )
        )
        .onAppear {
            syncDateText(from: memo.dateAssigned ?? Date())
            if let c = memo.customer {
                customerSearchText = c.displayName
            }
        }
    }

    private var customerField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Customer").font(AppTypography.caption).foregroundStyle(AppColors.inkSubtle)
            ZStack(alignment: .topLeading) {
                HStack(spacing: AppSpacing.standard) {
                    ZStack(alignment: .leading) {
                        // Main text field with customer name shown inline
                        TextField("Search customers...", text: $customerSearchText)
                            .textFieldStyle(.plain)
                            .font(AppTypography.smallValue)
                            .foregroundStyle(AppColors.ink)
                            .glassField()
                            .frame(width: 200)
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
                    }
                    Button(action: { showAddCustomerSheet = true }) {
                        Image(systemName: "plus.circle").foregroundStyle(AppColors.primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add Customer")
                }

                // Dropdown
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
                                .background(AppColors.cardBackground)
                            }
                        }
                    }
                    .frame(minWidth: 200, maxWidth: 200, maxHeight: 150)
                    .background(AppColors.panelBackground.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.small))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppCornerRadius.small)
                            .strokeBorder(AppColors.cardStroke, lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.3), radius: 8)
                    .offset(y: 36)
                    .zIndex(10)
                }
            }
        }
    }

    private var dateField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Date").font(AppTypography.caption).foregroundStyle(AppColors.inkSubtle)
            HStack(spacing: 0) {
                TextField("MM/DD/YYYY", text: $dateText)
                    .textFieldStyle(.plain)
                    .font(AppTypography.smallValue)
                    .foregroundStyle(AppColors.ink)
                    .frame(width: 100)
                    .onSubmit { parseDateText() }
                    .onChange(of: dateText) { _, _ in dateError = nil }
                    .onKeyPress(.tab) {
                        parseDateText()
                        return .ignored
                    }

                Button {
                    showDatePicker.toggle()
                } label: {
                    Image(systemName: "calendar")
                        .foregroundStyle(AppColors.primary)
                        .font(AppTypography.caption)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showDatePicker) {
                    DatePicker("", selection: Binding(
                        get: { memo.dateAssigned ?? Date() },
                        set: { newDate in
                            memo.dateAssigned = newDate
                            syncDateText(from: newDate)
                            showDatePicker = false
                            markDirty()
                        }
                    ), displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.graphical)
                    .padding(AppSpacing.section)
                }
            }
            .padding(AppSpacing.comfortable)
            .background(
                RoundedRectangle(cornerRadius: AppCornerRadius.field, style: .continuous)
                    .fill(AppColors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppCornerRadius.field, style: .continuous)
                    .strokeBorder(AppColors.cardStroke, lineWidth: 1)
            )
            .frame(width: 150)

            if let error = dateError {
                Text(error)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.danger)
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

        if let date = formatter.date(from: trimmed) {
            memo.dateAssigned = date
            syncDateText(from: date)
            dateError = nil
            markDirty()
            return
        }

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
        VStack(alignment: .leading, spacing: AppSpacing.comfortable) {
            HStack {
                SectionHeader(title: "Line Items")
                Spacer()
                addItemsMenu
            }

            if !selectedItemIDs.isEmpty {
                selectedItemActions
            }

            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 0) {
                // Header row
                GridRow {
                    Text("#")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.inkSubtle)
                        .frame(width: 28, alignment: .center)
                    Text("SKU").font(AppTypography.caption).foregroundStyle(AppColors.inkSubtle)
                    Text("Type").font(AppTypography.caption).foregroundStyle(AppColors.inkSubtle)
                    Text("Description").font(AppTypography.caption).foregroundStyle(AppColors.inkSubtle)
                        .frame(minWidth: 200, idealWidth: 400, maxWidth: .infinity, alignment: .leading)
                    Text("Carats").font(AppTypography.caption).foregroundStyle(AppColors.inkSubtle)
                        .frame(width: 70, alignment: .trailing)
                    Text("Rate").font(AppTypography.caption).foregroundStyle(AppColors.inkSubtle)
                        .frame(width: 80, alignment: .trailing)
                    Text("Amount").font(AppTypography.caption).foregroundStyle(AppColors.inkSubtle)
                        .frame(width: 110, alignment: .trailing)
                    Color.clear.frame(width: 28) // trash placeholder
                }
                .padding(.horizontal, AppSpacing.comfortable)
                .padding(.vertical, AppSpacing.compact)
                .background(AppColors.cardElevated)

                Divider()

                // Data rows
                ForEach(Array(memo.lineItems.enumerated()), id: \.element.id) { index, item in
                    EditableLineItemRow(
                        item: item,
                        rowNumber: index + 1,
                        onUpdate: { markDirty() },
                        onDelete: {
                            do {
                                try TransactionService.removeLineItem(item, modelContext: modelContext)
                                markDirty()
                            } catch {
                                showToast("Failed to remove item: \(ErrorMapper.userMessage(from: error))", isError: true)
                            }
                        }
                    )
                    .frame(minHeight: 44)
                    .padding(.horizontal, AppSpacing.comfortable)

                    Divider().padding(.horizontal, AppSpacing.comfortable)
                }

                // Add item row
                Divider().padding(.horizontal, AppSpacing.comfortable)
                HStack {
                    Menu {
                        Button("Single/Pair") { showInventorySheet = true }
                        Button("Lot") { showLotSheet = true }
                        Button("Brokered") {
                            do {
                                try TransactionService.addBrokeredLine(to: memo, modelContext: modelContext)
                                markDirty()
                            } catch {
                                showToast("Failed to add brokered line: \(ErrorMapper.userMessage(from: error))", isError: true)
                            }
                        }
                        Button("Service") {
                            do {
                                try TransactionService.addServiceLine(to: memo, modelContext: modelContext)
                                markDirty()
                            } catch {
                                showToast("Failed to add service line: \(ErrorMapper.userMessage(from: error))", isError: true)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 16))
                            Text("Add Item")
                                .font(AppTypography.body)
                        }
                        .foregroundStyle(AppColors.accent)
                    }
                    .menuStyle(.borderlessButton)
                    Spacer()
                }
                .frame(height: 44)
                .padding(.horizontal, AppSpacing.comfortable)
            }

            if memo.lineItems.isEmpty {
                Text("No line items. Add stones or services above.")
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.inkSubtle)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.hero)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.section)
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                        .strokeBorder(AppColors.cardStroke, lineWidth: 1)
                )
        )
    }

    private var addItemsMenu: some View {
        HStack(spacing: 2) {
            addButton("Single/Pair") { showInventorySheet = true }
            addButton("Lot") { showLotSheet = true }
            addButton("Brokered") {
                do {
                    try TransactionService.addBrokeredLine(to: memo, modelContext: modelContext)
                    markDirty()
                } catch {
                    showToast("Failed to add brokered line: \(ErrorMapper.userMessage(from: error))", isError: true)
                }
            }
            addButton("Service") {
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

    private func addButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(AppTypography.caption)
                .fontWeight(.medium)
                .foregroundStyle(AppColors.primary)
                .padding(.horizontal, AppSpacing.comfortable)
                .padding(.vertical, AppSpacing.standard)
        }
        .buttonStyle(.plain)
    }

    private var selectedItemActions: some View {
        HStack(spacing: AppSpacing.comfortable) {
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
            Button("Convert to Invoice") {
                guard !isConverting else { return }
                isConverting = true
                let items = memo.lineItems.filter { selectedItemIDs.contains($0.persistentModelID) && $0.status == .open }
                do {
                    if let invoice = try MemoService.convertToInvoice(memo: memo, selectedItems: items, modelContext: modelContext) {
                        guard !openDocTracker.isOpen(invoiceID: invoice.persistentModelID) else { return }
                        openWindow(id: "invoice", value: invoice.persistentModelID)
                    }
                } catch {
                    showToast("Failed to convert to invoice: \(ErrorMapper.userMessage(from: error))", isError: true)
                }
                selectedItemIDs.removeAll()
                isConverting = false
            }
            .buttonStyle(.gradient)
            .disabled(isConverting)
        }
        .padding(.vertical, AppSpacing.standard)
    }

    // MARK: - Totals

    private var totalsSection: some View {
        HStack {
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("Subtotal: \(memo.totalAmount.asCurrency)")
                    .font(AppTypography.heading)
                    .foregroundStyle(AppColors.ink)
                Text("\(memo.lineItems.count) item\(memo.lineItems.count == 1 ? "" : "s")")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.inkSubtle)
            }
        }
        .padding(AppSpacing.section)
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                        .strokeBorder(AppColors.cardStroke, lineWidth: 1)
                )
        )
    }

    // MARK: - Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Notes").font(AppTypography.caption).foregroundStyle(AppColors.inkSubtle)
            TextEditor(text: $memo.notes)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.ink)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 60)
                .onChange(of: memo.notes) { _, _ in markDirty() }
        }
        .padding(AppSpacing.section)
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                        .strokeBorder(AppColors.cardStroke, lineWidth: 1)
                )
        )
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

            Button("Email PDF") { emailMemoPDF() }
                .buttonStyle(.outline)
                .disabled(isGeneratingPDF)

            Button("Cancel") { handleCancel() }
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
            Button("Save & Exit") {
                saveMemo()
                dismiss()
            }
            Button("Discard", role: .destructive) {
                hasUnsavedEdits = false
                dirtyTracker.clearMemoDirty()
                dismiss()
            }
        } message: {
            Text("You have unsaved changes.")
        }
    }

    // MARK: - Actions

    private func handleCancel() {
        if hasUnsavedEdits {
            showUnsavedAlert = true
        } else {
            dismiss()
        }
    }

    private func saveMemo() {
        if requireSalesperson && (memo.salesperson ?? "").trimmingCharacters(in: .whitespaces).isEmpty {
            showToast("Salesperson is required", isError: true)
            return
        }
        do {
            try modelContext.save()
            hasUnsavedEdits = false
            dirtyTracker.clearMemoDirty()
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
