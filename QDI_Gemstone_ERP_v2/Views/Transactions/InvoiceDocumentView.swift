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
    @State private var isEditingEnabled: Bool = true
    @State private var isGeneratingPDF = false
    @State private var pdfError: String?
    @State private var toastMessage: String?
    @State private var toastIsError = false
    @State private var totalRefreshID = UUID()
    @State private var hasUnsavedEdits = false
    @State private var isSaving = false
    @State private var showUnsavedAlert = false
    @AccessibilityFocusState private var isHeaderFocused: Bool

    private var isEditable: Bool {
        invoice.status == .draft && isEditingEnabled
    }

    private var filteredCustomers: [Customer] {
        let q = customerSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return allCustomers }
        return allCustomers.filter { $0.displayName.lowercased().contains(q) }
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
                        VStack(alignment: .leading, spacing: AppSpacing.hero) {
                            headerSection
                            lineItemsSection
                            totalsSection
                            PaymentListView(invoice: invoice, onDirty: { markDirty() })
                            notesSection
                        }
                        .padding(AppSpacing.hero)
                    }
                    bottomToolbar
                }
            }
        }
        .accessibilityIdentifier("InvoiceDocumentView")
        .onAppear { isHeaderFocused = true }
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
                    showToast("⚠️ Zero price: \(zeroPriceSkus.joined(separator: ", "))", isError: false)
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
        .onChange(of: pdfError) { _, newVal in
            if let err = newVal {
                showToast(err, isError: true)
                pdfError = nil
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        GlassCard(padding: AppSpacing.hero) {
            VStack(alignment: .leading, spacing: AppSpacing.section) {
                HStack {
                    Text(verbatim: "Invoice \(invoice.referenceNumber)")
                        .font(AppTypography.heading)
                        .foregroundStyle(AppColors.ink)
                        .accessibilityFocused($isHeaderFocused)
                    Spacer()
                    invoiceStatusBadge
                }

                HStack(spacing: AppSpacing.hero) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Customer").font(AppTypography.caption).foregroundStyle(AppColors.inkSubtle)
                        VStack(spacing: AppSpacing.compact) {
                            TextField("Search customers...", text: $customerSearchText)
                                .textFieldStyle(.plain)
                                .font(AppTypography.smallValue)
                                .foregroundStyle(AppColors.ink)
                                .glassField()
                                .frame(width: 200)
                                .disabled(!isEditable)
                            HStack {
                                Picker("Customer", selection: Binding(
                                    get: { invoice.customer },
                                    set: { invoice.customer = $0; markDirty() }
                                )) {
                                    Text("Select…").tag(Customer?.none)
                                    ForEach(filteredCustomers) { c in Text(c.displayName).tag(Customer?.some(c)) }
                                }
                                .labelsHidden()
                                .accessibilityLabel("Select Customer")
                                .disabled(!isEditable)
                                Button(action: { showAddCustomerSheet = true }) {
                                    Image(systemName: "plus.circle").foregroundStyle(AppColors.primary)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Add Customer")
                                .opacity(isEditable ? 1 : 0)
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Date").font(AppTypography.caption).foregroundStyle(AppColors.inkSubtle)
                        DatePicker("", selection: $invoice.invoiceDate, displayedComponents: .date)
                            .labelsHidden()
                            .disabled(!isEditable)
                            .onChange(of: invoice.invoiceDate) { _, _ in markDirty() }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Terms").font(AppTypography.caption).foregroundStyle(AppColors.inkSubtle)
                        Picker("", selection: $invoice.terms) {
                            Text("Net 30").tag("Net 30")
                            Text("Net 60").tag("Net 60")
                            Text("Due on Receipt").tag("Due on Receipt")
                            Text("COD").tag("COD")
                        }
                        .labelsHidden()
                        .accessibilityLabel("Payment Terms")
                        .disabled(!isEditable)
                        .onChange(of: invoice.terms) { _, _ in markDirty() }
                    }
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
        }
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
        GlassCard(padding: AppSpacing.section) {
            VStack(alignment: .leading, spacing: AppSpacing.comfortable) {
                HStack {
                    SectionHeader(title: "Line Items")
                    Spacer()
                    if isEditable { addItemsMenu }
                }

                HStack(spacing: 0) {
                    TableHeader(title: "SKU", width: TableColumn.sku)
                    TableHeader(title: "Type", width: TableColumn.type)
                    TableHeader(title: "Description", width: TableColumn.description)
                    TableHeader(title: "Carats", width: TableColumn.carat)
                    TableHeader(title: "Rate", width: TableColumn.price)
                    TableHeader(title: "Amount", width: TableColumn.price)
                }
                .padding(.horizontal, AppSpacing.comfortable)

                ForEach(invoice.lineItems) { item in
                    EditableLineItemRow(item: item) { markDirty() }
                        .padding(.horizontal, AppSpacing.comfortable)
                        .padding(.vertical, 2)
                        .contextMenu {
                            if isEditable {
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
                }

                if invoice.lineItems.isEmpty {
                    Text("No line items.")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.inkSubtle)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.hero)
                }
            }
        }
    }

    private var addItemsMenu: some View {
        HStack(spacing: 8) {
            Button("Single/Pair") { showInventorySheet = true }
            Button("Lot") { showLotSheet = true }
                .help("A group of similar stones sold by total carat weight")
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
        }
        .font(AppTypography.caption)
        .foregroundStyle(AppColors.primary)
        .buttonStyle(.plain)
    }

    // MARK: - Totals

    private var totalsSection: some View {
        GlassCard(padding: AppSpacing.section) {
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
                                    Text("−\(invoice.discountAmount.asCurrency)")
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
        }
    }

    // MARK: - Notes

    private var notesSection: some View {
        GlassCard(padding: AppSpacing.section) {
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
        }
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
                    .help("Cancel this invoice and return items to inventory")
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
                .help("Record payment received for this invoice")
            }

            Button("Export PDF") { exportPDF() }
                .buttonStyle(.outline)
                .disabled(isGeneratingPDF)
                .keyboardShortcut("p", modifiers: .command)
                .help("Generate a PDF document for printing or emailing")

            Button("Email PDF") { emailPDF() }
                .buttonStyle(.outline)
                .disabled(isGeneratingPDF)
                .help("Generate PDF and open email compose with attachment")

            Button("Cancel") {
                if hasUnsavedEdits {
                    showUnsavedAlert = true
                } else {
                    dismiss()
                }
            }
                .buttonStyle(.outline)

            Button("Save") { saveInvoice() }
                .buttonStyle(.gradient)
                .keyboardShortcut("s", modifiers: .command)
        }
        .padding(AppSpacing.section)
        .background(AppColors.panelBackground)
        .overlay(alignment: .top) { Divider().background(AppColors.cardElevated) }
        .alert("Unsaved Changes", isPresented: $showUnsavedAlert) {
            Button("Keep Editing", role: .cancel) {}
            Button("Discard", role: .destructive) { dismiss() }
        } message: {
            Text("You have unsaved changes. Discard them?")
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
                                pdfError = "Failed to save PDF: \(ErrorMapper.userMessage(from: error))"
                            }
                        }
                        PDFService.shared.cleanupTempFile(at: tempURL)
                    }
                case .failure(let error):
                    pdfError = "PDF generation failed: \(ErrorMapper.userMessage(from: error))"
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
                    // Cleanup temp file after a delay to allow sharing service to finish
                    DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
                        PDFService.shared.cleanupTempFile(at: tempURL)
                    }
                case .failure(let error):
                    pdfError = "PDF generation failed: \(ErrorMapper.userMessage(from: error))"
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
