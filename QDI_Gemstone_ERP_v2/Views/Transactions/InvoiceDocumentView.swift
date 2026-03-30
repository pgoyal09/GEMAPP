import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

struct InvoiceDocumentView: View {
    @Bindable var invoice: Invoice
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.documentDirtyTracker) private var dirtyTracker
    @Query(sort: \Customer.lastName) private var allCustomers: [Customer]

    @State private var showInventorySheet = false
    @State private var showLotSheet = false
    @State private var showAddCustomerSheet = false
    @State private var showDeleteConfirm = false
    @State private var showVoidConfirm = false
    @State private var isEditingEnabled: Bool = true
    @State private var isGeneratingPDF = false
    @State private var pdfError: String?
    @State private var toastMessage: String?
    @State private var toastIsError = false
    @State private var totalRefreshID = UUID()

    private var isEditable: Bool {
        invoice.status == .draft && isEditingEnabled
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.l) {
                    headerSection
                    lineItemsSection
                    totalsSection
                    notesSection
                }
                .padding(AppSpacing.l)
            }
            bottomToolbar
        }
        .id(totalRefreshID)
        .onChange(of: invoice.lineItems.count) { _, _ in totalRefreshID = UUID() }
        .sheet(isPresented: $showInventorySheet) {
            InventorySelectSheet { stones in
                for stone in stones {
                    do {
                        try TransactionService.addStone(stone, to: invoice, modelContext: modelContext)
                    } catch {
                        showToast("Failed to add stone: \(error.localizedDescription)", isError: true)
                    }
                }
                markDirty()
            }
        }
        .sheet(isPresented: $showLotSheet) {
            LotSelectSheet { lot, carats in
                do {
                    try LotService.addToInvoice(lot, carats: carats, invoice: invoice, modelContext: modelContext)
                } catch {
                    showToast("Failed to add lot: \(error.localizedDescription)", isError: true)
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
                    showToast("Failed to delete invoice: \(error.localizedDescription)", isError: true)
                }
            }
        }
        .alert("Void Invoice?", isPresented: $showVoidConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Void", role: .destructive) {
                do {
                    try InvoiceService.voidInvoice(invoice, modelContext: modelContext)
                } catch {
                    showToast("Failed to void invoice: \(error.localizedDescription)", isError: true)
                }
            }
        }
        .overlay {
            if let msg = toastMessage {
                ToastOverlay(message: msg, isError: toastIsError)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation { toastMessage = nil }
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
        GlassCard(padding: AppSpacing.l) {
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                HStack {
                    Text("Invoice \(invoice.referenceNumber)")
                        .font(AppTypography.heading)
                        .foregroundStyle(AppColors.ink)
                    Spacer()
                    invoiceStatusBadge
                }

                HStack(spacing: AppSpacing.l) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Customer").font(AppTypography.caption).foregroundStyle(AppColors.inkSubtle)
                        HStack {
                            Picker("Customer", selection: Binding(
                                get: { invoice.customer },
                                set: { invoice.customer = $0; markDirty() }
                            )) {
                                Text("Select…").tag(Customer?.none)
                                ForEach(allCustomers) { c in Text(c.displayName).tag(Customer?.some(c)) }
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
                }
            }
        }
    }

    @ViewBuilder
    private var invoiceStatusBadge: some View {
        let tone: StatusBadge.Tone = switch invoice.status {
        case .draft: .neutral
        case .sent: .accent
        case .paid: .success
        case .void: .danger
        }
        StatusBadge(title: invoice.status.rawValue, tone: tone)
    }

    // MARK: - Line Items

    private var lineItemsSection: some View {
        GlassCard(padding: AppSpacing.m) {
            VStack(alignment: .leading, spacing: AppSpacing.s) {
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
                .padding(.horizontal, AppSpacing.s)

                ForEach(invoice.lineItems) { item in
                    EditableLineItemRow(item: item) { markDirty() }
                        .padding(.horizontal, AppSpacing.s)
                        .padding(.vertical, 2)
                        .contextMenu {
                            if isEditable {
                                Button("Remove") {
                                    do {
                                        try TransactionService.removeLineItem(item, modelContext: modelContext)
                                        markDirty()
                                    } catch {
                                        showToast("Failed to remove item: \(error.localizedDescription)", isError: true)
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
                        .padding(.vertical, AppSpacing.l)
                }
            }
        }
    }

    private var addItemsMenu: some View {
        HStack(spacing: 8) {
            Button("Single/Pair") { showInventorySheet = true }
            Button("Lot") { showLotSheet = true }
            Button("Brokered") {
                do {
                    try TransactionService.addBrokeredLine(to: invoice, modelContext: modelContext)
                    markDirty()
                } catch {
                    showToast("Failed to add brokered line: \(error.localizedDescription)", isError: true)
                }
            }
            Button("Service") {
                do {
                    try TransactionService.addServiceLine(to: invoice, modelContext: modelContext)
                    markDirty()
                } catch {
                    showToast("Failed to add service line: \(error.localizedDescription)", isError: true)
                }
            }
        }
        .font(AppTypography.caption)
        .foregroundStyle(AppColors.primary)
        .buttonStyle(.plain)
    }

    // MARK: - Totals

    private var totalsSection: some View {
        GlassCard(padding: AppSpacing.m) {
            HStack {
                Spacer()
                Text("Total: \(invoice.totalAmount.asCurrency)")
                    .font(AppTypography.heading)
                    .foregroundStyle(AppColors.ink)
            }
        }
    }

    // MARK: - Notes

    private var notesSection: some View {
        GlassCard(padding: AppSpacing.m) {
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
                        showToast("Failed to mark as paid: \(error.localizedDescription)", isError: true)
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

            Button("Cancel") { dismiss() }
                .buttonStyle(.outline)

            Button("Save") { saveInvoice() }
                .buttonStyle(.gradient)
                .keyboardShortcut("s", modifiers: .command)
        }
        .padding(AppSpacing.m)
        .background(Color.white.opacity(0.02))
        .overlay(alignment: .top) { Divider().background(Color.white.opacity(0.06)) }
    }

    private func saveInvoice() {
        if invoice.status == .draft { invoice.status = .sent }
        InvoiceService.markConvertedItemsAsSold(invoice: invoice, modelContext: modelContext)
        InvoiceService.markLotItemsAsSold(invoice: invoice, modelContext: modelContext)
        do {
            try modelContext.save()
            dirtyTracker.clearDirty()
            NotificationCenter.default.post(name: .memoOrInvoiceDidSave, object: nil)
        } catch {}
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
                                pdfError = "Failed to save PDF: \(error.localizedDescription)"
                            }
                        }
                        PDFService.shared.cleanupTempFile(at: tempURL)
                    }
                case .failure(let error):
                    pdfError = "PDF generation failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func markDirty() {
        dirtyTracker.markDirty()
    }

    private func showToast(_ message: String, isError: Bool = false) {
        toastIsError = isError
        withAnimation { toastMessage = message }
    }
}
