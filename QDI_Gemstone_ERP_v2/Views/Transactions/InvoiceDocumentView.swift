import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

struct InvoiceDocumentView: View {
    @Bindable var invoice: Invoice
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.documentDirtyTracker) private var dirtyTracker
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
    @State private var lineItemTableWidth: CGFloat = 0

    private static let lineItemLayout = TableColumnLayout(columns: [
        ColumnDef("sku", weight: 2.0, minWidth: 80),
        ColumnDef("type", weight: 1.5, minWidth: 60),
        ColumnDef("description", weight: 3.0, minWidth: 120),
        ColumnDef("carats", weight: 1.2, minWidth: 55, alignment: .trailing),
        ColumnDef("rate", weight: 1.5, minWidth: 65, alignment: .trailing),
        ColumnDef("amount", weight: 1.5, minWidth: 65, alignment: .trailing),
    ], spacing: 4)

    private var lineItemWidths: [CGFloat] {
        let padding = AppSpacing.section * 2
        let hPad = AppSpacing.comfortable * 2
        let fixedCols: CGFloat = 28 + 28
        let spacing: CGFloat = 4 * 7
        let available = max(0, lineItemTableWidth - padding - hPad - fixedCols - spacing)
        return Self.lineItemLayout.widths(for: available)
    }

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
        .sheet(isPresented: $showInventorySheet) {
            InventorySelectSheet { stones in
                var zeroPriceSkus: [String] = []
                for stone in stones {
                    do {
                        try TransactionService.addStone(stone, to: invoice, modelContext: modelContext)
                        if stone.sellPrice == 0 { zeroPriceSkus.append(stone.sku) }
                    } catch {
                        showToast("Failed to add stone: \(ErrorMapper.userMessage(from: error))", isError: true)
                    }
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

                // Salesperson
                VStack(alignment: .leading, spacing: 4) {
                    Text("Salesperson").font(AppTypography.caption).foregroundStyle(AppColors.inkSubtle)
                    TextField("Salesperson name", text: Binding(
                        get: { invoice.salesperson ?? "" },
                        set: { invoice.salesperson = $0.isEmpty ? nil : $0; markDirty() }
                    ))
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
        VStack(alignment: .leading, spacing: 4) {
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
        VStack(alignment: .leading, spacing: 4) {
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

            // Table header
            HStack(spacing: 4) {
                Text("#")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.inkSubtle)
                    .frame(width: 28, alignment: .center)
                Text("SKU")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.inkSubtle)
                    .frame(width: lineItemWidths.indices.contains(0) ? lineItemWidths[0] : 60, alignment: .leading)
                Text("Type")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.inkSubtle)
                    .frame(width: lineItemWidths.indices.contains(1) ? lineItemWidths[1] : 60, alignment: .leading)
                Text("Description")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.inkSubtle)
                    .frame(width: lineItemWidths.indices.contains(2) ? lineItemWidths[2] : 60, alignment: .leading)
                Text("Carats")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.inkSubtle)
                    .frame(width: lineItemWidths.indices.contains(3) ? lineItemWidths[3] : 60, alignment: .trailing)
                Text("Rate")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.inkSubtle)
                    .frame(width: lineItemWidths.indices.contains(4) ? lineItemWidths[4] : 60, alignment: .trailing)
                Text("Amount")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.inkSubtle)
                    .frame(width: lineItemWidths.indices.contains(5) ? lineItemWidths[5] : 60, alignment: .trailing)
                Spacer().frame(width: 28)
            }
            .padding(.horizontal, AppSpacing.comfortable)
            .padding(.vertical, AppSpacing.compact)
            .background(AppColors.cardElevated)

            // Divider below header
            Divider().background(AppColors.cardStroke)

            // Rows
            ForEach(Array(invoice.lineItems.enumerated()), id: \.element.id) { index, item in
                VStack(spacing: 0) {
                    EditableLineItemRow(
                        item: item,
                        rowNumber: index + 1,
                        widths: lineItemWidths,
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
                    .frame(height: 44)
                    .padding(.horizontal, AppSpacing.comfortable)

                    if index < invoice.lineItems.count - 1 {
                        Divider().background(AppColors.cardStroke).padding(.horizontal, AppSpacing.comfortable)
                    }
                }
            }

            // Empty placeholder row
            VStack(spacing: 0) {
                Divider().background(AppColors.cardStroke).padding(.horizontal, AppSpacing.comfortable)
                HStack(spacing: 4) {
                    Text("\(invoice.lineItems.count + 1)")
                        .font(AppTypography.mono)
                        .foregroundStyle(AppColors.inkSubtle.opacity(0.5))
                        .frame(width: 28, alignment: .center)
                    Text("—")
                        .font(AppTypography.mono)
                        .foregroundStyle(AppColors.inkSubtle.opacity(0.5))
                        .frame(width: lineItemWidths.indices.contains(0) ? lineItemWidths[0] : 60, alignment: .leading)
                    Text("—")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.inkSubtle.opacity(0.5))
                        .frame(width: lineItemWidths.indices.contains(1) ? lineItemWidths[1] : 60, alignment: .leading)
                    Text("")
                        .frame(width: lineItemWidths.indices.contains(2) ? lineItemWidths[2] : 60)
                    Text("")
                        .frame(width: lineItemWidths.indices.contains(3) ? lineItemWidths[3] : 60)
                    Text("")
                        .frame(width: lineItemWidths.indices.contains(4) ? lineItemWidths[4] : 60)
                    Text("$0.00")
                        .font(AppTypography.mono)
                        .foregroundStyle(AppColors.inkSubtle.opacity(0.5))
                        .frame(width: lineItemWidths.indices.contains(5) ? lineItemWidths[5] : 60, alignment: .trailing)
                    Spacer().frame(width: 28)
                }
                .frame(height: 44)
                .padding(.horizontal, AppSpacing.comfortable)
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
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                    .fill(AppColors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                            .strokeBorder(AppColors.cardStroke, lineWidth: 1)
                    )
                    .onAppear { lineItemTableWidth = geo.size.width }
                    .onChange(of: geo.size.width) { _, w in lineItemTableWidth = w }
            }
        )
    }

    private var addItemsMenu: some View {
        HStack(spacing: 2) {
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
                VStack(alignment: .trailing, spacing: 4) {
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
                dirtyTracker.clearDirty()
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
            dirtyTracker.clearDirty()
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
