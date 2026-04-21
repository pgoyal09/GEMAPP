import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

struct InvoiceDocumentView: View {
    @Bindable var invoice: Invoice
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.documentDirtyTracker) private var dirtyTracker
    @Environment(\.openDocumentTracker) private var openDocTracker
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Customer.lastName) private var allCustomers: [Customer]

    @State private var showInventorySheet = false
    @State private var showLotSheet = false
    @State private var showAddCustomerSheet = false
    @State private var showDeleteConfirm = false
    @State private var showVoidConfirm = false
    @State private var customerSearchText = ""
    @State private var showCustomerDropdown = false
    @State private var isGeneratingPDF = false
    @State private var toastMessage: String?
    @State private var toastIsError = false
    @State private var totalRefreshID = UUID()
    @State private var hasUnsavedEdits = false
    @State private var isSaving = false
    @State private var showUnsavedAlert = false
    @State private var dateText = ""
    @State private var dateError: String?
    @State private var showDatePicker = false
    private var isEditable: Bool {
        invoice.status == .draft
    }

    private var isNewInvoice: Bool {
        invoice.lineItems.isEmpty && invoice.createdAt.timeIntervalSinceNow > -60
    }

    private var filteredCustomers: [Customer] {
        let q = customerSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return allCustomers }
        return allCustomers.filter { $0.displayName.lowercased().contains(q) }
    }

    private var inlineSuggestion: String? {
        let q = customerSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, invoice.customer == nil else { return nil }
        if let match = filteredCustomers.first,
           match.displayName.lowercased().hasPrefix(q.lowercased()) {
            return match.displayName
        }
        return nil
    }

    var body: some View {
        Group {
            if invoice.isDeleted {
                Text("Invoice no longer available")
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
                            PaymentListView(invoice: invoice, onDirty: { markDirty() })
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
        .accessibilityIdentifier("InvoiceDocumentView")
        .id(totalRefreshID)
        .onChange(of: invoice.lineItems.count) { _, _ in totalRefreshID = UUID() }
        .onReceive(NotificationCenter.default.publisher(for: .dataStoreDidChange)) { _ in
            totalRefreshID = UUID()
        }
        .sheet(isPresented: $showInventorySheet) {
            InventorySelectSheet { stones in
                var zeroPriceSkus: [String] = []
                var lockMessages: [String] = []
                for stone in stones {
                    if let lockingDoc = openDocTracker.lockingDocument(for: stone.persistentModelID) {
                        lockMessages.append("\(stone.sku) is open in \(lockingDoc)")
                        continue
                    }
                    do {
                        try TransactionService.addStone(stone, to: invoice, modelContext: modelContext)
                        openDocTracker.lockStone(stone.persistentModelID, by: "Invoice #\(invoice.referenceNumber)")
                        if stone.sellPrice == 0 { zeroPriceSkus.append(stone.sku) }
                    } catch {
                        showToast("Failed to add stone: \(ErrorMapper.userMessage(from: error))", isError: true)
                    }
                }
                if !lockMessages.isEmpty {
                    showToast(lockMessages.joined(separator: ", "), isError: true)
                }
                if !zeroPriceSkus.isEmpty {
                    showToast("Zero price: \(zeroPriceSkus.joined(separator: ", "))", isError: false)
                }
                markDirty()
            }
        }
        .sheet(isPresented: $showLotSheet) {
            LotSelectSheet { lot, carats in
                do {
                    try LotService.addToInvoice(lot, carats: carats, invoice: invoice, modelContext: modelContext)
                } catch {
                    showToast("Failed to add lot: \(ErrorMapper.userMessage(from: error))", isError: true)
                }
                markDirty()
            }
        }
        .sheet(isPresented: $showAddCustomerSheet) {
            CustomerFormSheet(mode: .add) { customer in
                invoice.customer = customer
                customerSearchText = customer.displayName
                markDirty()
            }
        }
        .alert("Delete Invoice?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                do {
                    try InvoiceService.deleteInvoice(invoice, modelContext: modelContext)
                    dismiss()
                } catch {
                    showToast("Failed to delete invoice: \(ErrorMapper.userMessage(from: error))", isError: true)
                }
            }
        }
        .alert("Void Invoice?", isPresented: $showVoidConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Void", role: .destructive) {
                do {
                    try InvoiceService.voidInvoice(invoice, modelContext: modelContext)
                } catch {
                    showToast("Failed to void invoice: \(ErrorMapper.userMessage(from: error))", isError: true)
                }
            }
        }
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
                Text("Invoice #\(invoice.referenceNumber)")
                    .font(AppTypography.heading)
                    .foregroundStyle(AppColors.ink)
                Spacer()
                if !isNewInvoice {
                    invoiceStatusBadge
                }
            }

            // Fields row (horizontal)
            HStack(spacing: AppSpacing.hero) {
                // Customer autocomplete
                customerField

                // Date field
                dateField

                // Terms
                VStack(alignment: .leading, spacing: AppSpacing.tableColumnGap) {
                    Text("Terms").font(AppTypography.caption).foregroundStyle(AppColors.inkSubtle)
                    TextField("Net 30", text: $invoice.terms)
                        .textFieldStyle(.plain)
                        .font(AppTypography.smallValue)
                        .foregroundStyle(AppColors.ink)
                        .glassField()
                        .frame(width: 100)
                        .disabled(!isEditable)
                        .onChange(of: invoice.terms) { _, _ in markDirty() }
                }

                // Due Date
                VStack(alignment: .leading, spacing: AppSpacing.tableColumnGap) {
                    Text("Due Date").font(AppTypography.caption).foregroundStyle(AppColors.inkSubtle)
                    DatePicker("", selection: Binding(
                        get: { invoice.dueDate ?? Calendar.current.date(byAdding: .day, value: 30, to: invoice.invoiceDate) ?? Date() },
                        set: { invoice.dueDate = $0; markDirty() }
                    ), displayedComponents: .date)
                    .labelsHidden()
                    .colorScheme(.dark)
                    .tint(AppColors.ink)
                    .foregroundStyle(AppColors.ink)
                    .environment(\.colorScheme, .dark)
                    .glassField()
                    .frame(width: 150)
                    .disabled(!isEditable)
                }

                // Salesperson
                VStack(alignment: .leading, spacing: AppSpacing.tableColumnGap) {
                    Text("Salesperson").font(AppTypography.caption).foregroundStyle(AppColors.inkSubtle)
                    TextField("Salesperson name", text: Binding(
                        get: { invoice.salesperson ?? "" },
                        set: { invoice.salesperson = $0.isEmpty ? nil : $0; markDirty() }
                    ))
                    .textFieldStyle(.plain)
                    .font(AppTypography.smallValue)
                    .foregroundStyle(AppColors.ink)
                    .glassField()
                    .frame(width: 160)
                    .disabled(!isEditable)
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
            syncDateText(from: invoice.invoiceDate)
            if let c = invoice.customer {
                customerSearchText = c.displayName
            }
        }
    }

    private var customerField: some View {
        VStack(alignment: .leading, spacing: AppSpacing.tableColumnGap) {
            Text("Customer").font(AppTypography.caption).foregroundStyle(AppColors.inkSubtle)
            ZStack(alignment: .topLeading) {
                HStack(spacing: AppSpacing.standard) {
                    ZStack(alignment: .leading) {
                        TextField("Search customers...", text: $customerSearchText)
                            .textFieldStyle(.plain)
                            .font(AppTypography.smallValue)
                            .foregroundStyle(AppColors.ink)
                            .glassField()
                            .frame(width: 200)
                            .disabled(!isEditable)
                            .overlay(alignment: .trailing) {
                                if invoice.customer != nil && isEditable {
                                    Button {
                                        invoice.customer = nil
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
                                if let c = invoice.customer, trimmed != c.displayName {
                                    invoice.customer = nil
                                    markDirty()
                                }
                                showCustomerDropdown = !trimmed.isEmpty && invoice.customer == nil && isEditable
                            }
                            .onKeyPress(.tab) {
                                guard isEditable else { return .ignored }
                                if let match = filteredCustomers.first, invoice.customer == nil {
                                    invoice.customer = match
                                    customerSearchText = match.displayName
                                    showCustomerDropdown = false
                                    markDirty()
                                    return .handled
                                }
                                return .ignored
                            }
                    }
                    if isEditable {
                        Button(action: { showAddCustomerSheet = true }) {
                            Image(systemName: "plus.circle").foregroundStyle(AppColors.primary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Add Customer")
                    }
                }

                // Dropdown
                if showCustomerDropdown && !filteredCustomers.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(filteredCustomers) { c in
                                Button {
                                    invoice.customer = c
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
        VStack(alignment: .leading, spacing: AppSpacing.tableColumnGap) {
            Text("Date").font(AppTypography.caption).foregroundStyle(AppColors.inkSubtle)
            HStack(spacing: 0) {
                TextField("MM/DD/YYYY", text: $dateText)
                    .textFieldStyle(.plain)
                    .font(AppTypography.smallValue)
                    .foregroundStyle(AppColors.ink)
                    .frame(width: 100)
                    .disabled(!isEditable)
                    .onSubmit { parseDateText() }
                    .onChange(of: dateText) { _, _ in dateError = nil }

                Button {
                    showDatePicker.toggle()
                } label: {
                    Image(systemName: "calendar")
                        .foregroundStyle(AppColors.primary)
                        .font(AppTypography.caption)
                }
                .buttonStyle(.plain)
                .disabled(!isEditable)
                .popover(isPresented: $showDatePicker) {
                    DatePicker("", selection: Binding(
                        get: { invoice.invoiceDate },
                        set: { newDate in
                            invoice.invoiceDate = newDate
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
            invoice.invoiceDate = date
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
                invoice.invoiceDate = date
                syncDateText(from: date)
                dateError = nil
                markDirty()
                return
            }
        }

        dateError = "Invalid date. Use MM/DD/YYYY"
    }

    @ViewBuilder
    private var invoiceStatusBadge: some View {
        if invoice.isDeleted {
            EmptyView()
        } else {
            let tone: StatusBadge.Tone = switch invoice.status {
            case .draft: .neutral
            case .sent: .accent
            case .paid: .success
            case .void: .danger
            }
            StatusBadge(title: invoice.status.rawValue, tone: tone)
        }
    }

    // MARK: - Line Items

    private var lineItemsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.comfortable) {
            HStack {
                SectionHeader(title: "Line Items")
                Spacer()
                if isEditable { addItemsMenu }
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
                    Color.clear.frame(width: 28)
                }
                .padding(.horizontal, AppSpacing.comfortable)
                .padding(.vertical, AppSpacing.compact)
                .background(AppColors.cardElevated)

                Divider()

                // Data rows
                ForEach(Array(invoice.lineItems.enumerated()), id: \.element.id) { index, item in
                    EditableLineItemRow(
                        item: item,
                        rowNumber: index + 1,
                        onUpdate: { markDirty() },
                        onDelete: isEditable ? {
                            do {
                                try TransactionService.removeLineItem(item, modelContext: modelContext)
                                markDirty()
                            } catch {
                                showToast("Failed to remove item: \(ErrorMapper.userMessage(from: error))", isError: true)
                            }
                        } : nil
                    )
                    .frame(minHeight: 44)
                    .padding(.horizontal, AppSpacing.comfortable)

                    Divider().padding(.horizontal, AppSpacing.comfortable)
                }

                // Add item row
                Divider().padding(.horizontal, AppSpacing.comfortable)
                if isEditable {
                    HStack {
                        Menu {
                            Button("Single/Pair") { showInventorySheet = true }
                            Button("Lot") { showLotSheet = true }
                            Button("Brokered") {
                                do {
                                    try TransactionService.addBrokeredLine(to: invoice, modelContext: modelContext)
                                    markDirty()
                                } catch {
                                    showToast("Failed to add brokered line: \(ErrorMapper.userMessage(from: error))", isError: true)
                                }
                            }
                            Button("Service") {
                                do {
                                    try TransactionService.addServiceLine(to: invoice, modelContext: modelContext)
                                    markDirty()
                                } catch {
                                    showToast("Failed to add service line: \(ErrorMapper.userMessage(from: error))", isError: true)
                                }
                            }
                        } label: {
                            HStack(spacing: AppSpacing.tableColumnGap) {
                                Image(systemName: "plus.circle.fill")
                                    .font(AppTypography.heading)
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
            }

            if invoice.lineItems.isEmpty {
                Text("No line items.")
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
        HStack(spacing: AppSpacing.tight) {
            addButton("Single/Pair") { showInventorySheet = true }
            addButton("Lot") { showLotSheet = true }
            addButton("Brokered") {
                do {
                    try TransactionService.addBrokeredLine(to: invoice, modelContext: modelContext)
                    markDirty()
                } catch {
                    showToast("Failed to add brokered line: \(ErrorMapper.userMessage(from: error))", isError: true)
                }
            }
            addButton("Service") {
                do {
                    try TransactionService.addServiceLine(to: invoice, modelContext: modelContext)
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

    // MARK: - Totals

    private var totalsSection: some View {
        VStack(alignment: .trailing, spacing: AppSpacing.comfortable) {
            HStack {
                Spacer()
                VStack(alignment: .trailing, spacing: AppSpacing.tableColumnGap) {
                    HStack {
                        Text("Subtotal")
                            .font(AppTypography.body)
                            .foregroundStyle(AppColors.inkMuted)
                        Text(invoice.totalBeforeDiscount.asCurrency)
                            .font(AppTypography.mono)
                            .foregroundStyle(AppColors.ink)
                    }

                    Text("\(invoice.lineItems.count) item\(invoice.lineItems.count == 1 ? "" : "s")")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.inkSubtle)

                    if isEditable || invoice.discountAmount > 0 {
                        HStack(spacing: AppSpacing.comfortable) {
                            Text("Discount")
                                .font(AppTypography.body)
                                .foregroundStyle(AppColors.inkMuted)
                            if isEditable {
                                TextField("0.00", value: $invoice.discountAmount, format: .number)
                                    .glassField()
                                    .frame(width: 100)
                                    .multilineTextAlignment(.trailing)
                                    .onChange(of: invoice.discountAmount) { _, _ in markDirty() }
                            } else {
                                Text("\u{2212}\(invoice.discountAmount.asCurrency)")
                                    .font(AppTypography.mono)
                                    .foregroundStyle(AppColors.danger)
                            }
                        }
                    }

                    if isEditable || invoice.taxRate > 0 {
                        HStack(spacing: AppSpacing.comfortable) {
                            Text("Tax Rate %")
                                .font(AppTypography.body)
                                .foregroundStyle(AppColors.inkMuted)
                            if isEditable {
                                TextField("0.0", value: $invoice.taxRate, format: .number)
                                    .glassField()
                                    .frame(width: 80)
                                    .multilineTextAlignment(.trailing)
                                    .onChange(of: invoice.taxRate) { _, _ in markDirty() }
                            } else {
                                Text(verbatim: "\(invoice.taxRate)%")
                                    .font(AppTypography.mono)
                                    .foregroundStyle(AppColors.inkMuted)
                            }
                        }
                    }

                    if invoice.taxAmount > 0 {
                        HStack {
                            Text("Tax")
                                .font(AppTypography.body)
                                .foregroundStyle(AppColors.inkMuted)
                            Text(invoice.taxAmount.asCurrency)
                                .font(AppTypography.mono)
                                .foregroundStyle(AppColors.ink)
                        }
                    }

                    Divider().frame(width: 200)

                    HStack {
                        Text("Total")
                            .font(AppTypography.heading)
                            .foregroundStyle(AppColors.ink)
                        Text(invoice.grandTotal.asCurrency)
                            .font(AppTypography.heading)
                            .foregroundStyle(AppColors.ink)
                    }
                }
            }
        }
        .padding(.horizontal, AppSpacing.hero)
        .padding(.vertical, AppSpacing.section)
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
        VStack(alignment: .leading, spacing: AppSpacing.tableColumnGap) {
            Text("Notes").font(AppTypography.caption).foregroundStyle(AppColors.inkSubtle)
            TextEditor(text: $invoice.notes)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.ink)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 60)
                .disabled(!isEditable)
                .onChange(of: invoice.notes) { _, _ in markDirty() }
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
            Button("Delete") { showDeleteConfirm = true }
                .foregroundStyle(AppColors.danger)
                .buttonStyle(.plain)

            if invoice.status != .void {
                Button("Void") { showVoidConfirm = true }
                    .buttonStyle(.outline(AppColors.danger))
            }

            Spacer()

            if invoice.status == .sent {
                Button("Mark as Paid") {
                    do {
                        try InvoiceService.markAsPaid(invoice, modelContext: modelContext)
                        InvoiceService.markConvertedItemsAsSold(invoice: invoice, modelContext: modelContext)
                        InvoiceService.markLotItemsAsSold(invoice: invoice, modelContext: modelContext)
                        NotificationCenter.default.post(name: .memoOrInvoiceDidSave, object: nil)
                    } catch {
                        showToast("Failed to mark as paid: \(ErrorMapper.userMessage(from: error))", isError: true)
                    }
                }
                .buttonStyle(.gradient(AppColors.emeraldGradient))
            }

            Button("Export PDF") { exportPDF() }
                .buttonStyle(.outline)
                .disabled(isGeneratingPDF)
                .keyboardShortcut("p", modifiers: .command)

            Button("Email PDF") { emailPDF() }
                .buttonStyle(.outline)
                .disabled(isGeneratingPDF)

            Button("Cancel") { handleCancel() }
                .buttonStyle(.outline)
                .disabled(isSaving)

            Button("Save") {
                guard !isSaving else { return }
                isSaving = true
                defer { isSaving = false }
                saveInvoice()
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
                saveInvoice()
                dismiss()
            }
            Button("Discard", role: .destructive) {
                hasUnsavedEdits = false
                dirtyTracker.clearInvoiceDirty()
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

    private func saveInvoice() {
        if invoice.status == .draft { invoice.status = .sent }
        InvoiceService.markConvertedItemsAsSold(invoice: invoice, modelContext: modelContext)
        InvoiceService.markLotItemsAsSold(invoice: invoice, modelContext: modelContext)
        do {
            try modelContext.save()
            hasUnsavedEdits = false
            dirtyTracker.clearInvoiceDirty()
            NotificationCenter.default.post(name: .memoOrInvoiceDidSave, object: nil)
            NotificationCenter.default.post(name: .dataStoreDidChange, object: nil)
        } catch {
            showToast("Failed to save invoice: \(ErrorMapper.userMessage(from: error))", isError: true)
        }
    }

    private func exportPDF() {
        isGeneratingPDF = true
        PDFService.shared.generatePDF(invoice: invoice) { result in
            DispatchQueue.main.async {
                isGeneratingPDF = false
                switch result {
                case .success(let tempURL):
                    let panel = NSSavePanel()
                    panel.allowedContentTypes = [.pdf]
                    panel.nameFieldStringValue = "Invoice-\(invoice.referenceNumber).pdf"
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

    private func emailPDF() {
        isGeneratingPDF = true
        PDFService.shared.generatePDF(invoice: invoice) { result in
            DispatchQueue.main.async {
                isGeneratingPDF = false
                switch result {
                case .success(let tempURL):
                    let service = NSSharingService(named: .composeEmail)
                    if let service = service {
                        service.recipients = [invoice.customer?.email].compactMap { $0?.isEmpty == false ? $0 : nil }
                        service.subject = "Invoice \(invoice.referenceNumber)"
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
