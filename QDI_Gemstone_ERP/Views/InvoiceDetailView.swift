import SwiftUI
import SwiftData
import AppKit

struct InvoiceDetailView: View {
    let invoice: Invoice
    var onUpdate: (() -> Void)?
    /// Called when view is dismissed (e.g. sheet). Parent should clear binding so sheet doesn't reopen.
    var onDismiss: (() -> Void)?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.documentDirtyTracker) private var documentDirtyTracker
    @Query(sort: \Customer.lastName) private var customers: [Customer]
    @State private var generatedPDFURL: URL?
    @State private var pdfError: String?
    @State private var isGeneratingPDF = false
    @State private var showInventorySheet = false
    @State private var showAddCustomerSheet = false
    @State private var showLeaveWithoutSavingAlert = false
    @State private var showDeleteConfirm = false
    @State private var totalRefreshID = 0
    @State private var hasUnsavedEdits = false

    private var isDirty: Bool { modelContext.hasChanges || hasUnsavedEdits }

    /// Dismisses the view: when onDismiss is set (sheet), clears parent binding; else closes window.
    private func performDismiss() {
        modelContext.rollback()
        documentDirtyTracker?.hasUnsavedInvoice = false
        if let onDismiss {
            onDismiss()
        } else {
            NSApp.keyWindow?.close()
        }
    }

    private var isCreateMode: Bool { invoice.customer == nil }
    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: value as NSDecimalNumber) ?? "$0"
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: AppSpacing.s) {
                    Text("INVOICE")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    Text(displayTitle)
                        .font(.title)
                        .fontWeight(.bold)
                }
                Spacer()
                Text(invoice.effectiveStatus.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(invoice.effectiveStatus == .paid ? Color.green : .secondary)
            }
            if isCreateMode {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Bill To")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        Picker("", selection: Binding(
                            get: { invoice.customer },
                            set: { invoice.customer = $0; hasUnsavedEdits = true; onUpdate?() }
                        )) {
                            Text("Select customer…").tag(nil as Customer?)
                            ForEach(customers, id: \.id) { c in
                                Text(c.displayName).tag(c as Customer?)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 220)
                        Button {
                            showAddCustomerSheet = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(AppColors.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else if let customer = invoice.customer {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bill To")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(customer.displayName)
                        .font(.headline)
                    if let email = customer.email, !email.isEmpty {
                        Text(email)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            HStack(spacing: AppSpacing.xl) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Date")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if isCreateMode {
                        DatePicker("", selection: Binding(
                            get: { invoice.invoiceDate },
                            set: { invoice.invoiceDate = $0; hasUnsavedEdits = true; onUpdate?() }
                        ), displayedComponents: .date)
                        .labelsHidden()
                    } else {
                        Text(invoice.invoiceDate, style: .date)
                    }
                }
                if isCreateMode {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Terms")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Picker("", selection: Binding(
                            get: { invoice.terms ?? "Net 30" },
                            set: { invoice.terms = $0; hasUnsavedEdits = true; onUpdate?() }
                        )) {
                            Text("Net 30").tag("Net 30")
                            Text("Net 60").tag("Net 60")
                            Text("Due on receipt").tag("Due on receipt")
                            Text("COD").tag("COD")
                        }
                        .pickerStyle(.menu)
                        .frame(width: 140)
                    }
                } else if let due = invoice.dueDate {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Due Date")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(due, style: .date)
                    }
                }
                if let terms = invoice.terms, !terms.isEmpty, !isCreateMode {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Terms")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(terms)
                    }
                }
            }
        }
        .padding(AppSpacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(AppCornerRadius.l)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppSpacing.xl) {
                // Header card (QuickBooks-like document)
                headerSection
                .padding(AppSpacing.l)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
                .cornerRadius(AppCornerRadius.l)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                
                // Line items
                lineItemsSection
                
                // Totals
                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Total")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(formatCurrency(invoice.lineItems.reduce(Decimal(0)) { $0 + $1.amount }))
                            .font(.title2.bold())
                    }
                    .id(totalRefreshID)
                }
                .padding(AppSpacing.l)
                
                if let notes = invoice.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: AppSpacing.s) {
                        Text("Notes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(notes)
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppSpacing.l)
                }
            }
            .padding(AppSpacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minWidth: 480)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.98))
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    if isDirty {
                        showLeaveWithoutSavingAlert = true
                    } else {
                        performDismiss()
                    }
                }
                .keyboardShortcut(.cancelAction)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    do {
                        try modelContext.save()
                        hasUnsavedEdits = false
                        onUpdate?()
                        NotificationCenter.default.post(name: .memoOrInvoiceDidSave, object: nil)
                    } catch {
                        pdfError = error.localizedDescription
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
            ToolbarItem(placement: .primaryAction) {
                if invoice.effectiveStatus != .paid && invoice.effectiveStatus != .void {
                    Button("Mark as Paid") {
                        markAsPaid()
                    }
                }
            }
            ToolbarItem(placement: .destructiveAction) {
                if invoice.effectiveStatus != .paid && invoice.effectiveStatus != .void {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            ToolbarItem(placement: .automatic) {
                Button {
                    exportPDF()
                } label: {
                    Label("Print / Export PDF", systemImage: "square.and.arrow.up")
                }
                .disabled(isGeneratingPDF)
            }
        }
        .sheet(item: Binding(get: { generatedPDFURL.map(IdentifiableURL.init) }, set: { generatedPDFURL = $0?.url })) { identifiable in
            PDFExportSheet(pdfURL: identifiable.url)
        }
        .alert("PDF Export Failed", isPresented: Binding(get: { pdfError != nil }, set: { if !$0 { pdfError = nil } })) {
            Button("OK", role: .cancel) { pdfError = nil }
        } message: {
            if let msg = pdfError { Text(msg) }
        }
        .sheet(isPresented: $showAddCustomerSheet) {
            NavigationStack {
                AddCustomerSheet { newCustomer in
                    invoice.customer = newCustomer
                    hasUnsavedEdits = true
                    onUpdate?()
                }
            }
        }
        .onExitCommand {
            if isDirty {
                showLeaveWithoutSavingAlert = true
            } else {
                performDismiss()
            }
        }
        .alert("Leave without saving?", isPresented: $showLeaveWithoutSavingAlert) {
            Button("Keep Editing", role: .cancel) {}
            Button("Discard", role: .destructive) {
                performDismiss()
            }
        } message: {
            Text("Your changes will not be saved.")
        }
        .alert("Delete Invoice?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteInvoice()
            }
        } message: {
            Text("Line items will be returned to inventory. This cannot be undone.")
        }
        .onChange(of: isDirty) { _, dirty in
            documentDirtyTracker?.hasUnsavedInvoice = dirty
        }
        .onAppear {
            documentDirtyTracker?.hasUnsavedInvoice = isDirty
        }
        .onDisappear {
            documentDirtyTracker?.hasUnsavedInvoice = false
        }
    }

    private var lineItemsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            Text("Line Items")
                .font(.headline)
            if invoice.lineItems.isEmpty {
                Text("No line items")
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                LazyVStack(spacing: 0) {
                    invoiceLineItemsTableHeader
                    Divider()
                    ForEach(invoice.lineItems.sorted(by: { $0.displaySku < $1.displaySku }), id: \.id) { item in
                        EditableLineItemRow(item: item, persistOnEdit: false, onUpdate: { totalRefreshID += 1; hasUnsavedEdits = true; onUpdate?() })
                            .contextMenu {
                                Button("Delete", role: .destructive) {
                                    removeLineItem(item)
                                    totalRefreshID += 1
                                    hasUnsavedEdits = true
                                }
                            }
                        Divider()
                    }
                }
            }
            if invoice.effectiveStatus != .paid && invoice.effectiveStatus != .void {
                HStack(spacing: AppSpacing.m) {
                    Button("+ From Inventory") { showInventorySheet = true }
                        .buttonStyle(.borderless)
                    Button("+ Brokered Stone") {
                        TransactionViewModel.addBrokeredLineToInvoice(invoice, modelContext: modelContext, persistImmediately: false)
                        totalRefreshID += 1
                        hasUnsavedEdits = true
                        onUpdate?()
                    }
                    .buttonStyle(.borderless)
                    Button("+ Custom Line") {
                        TransactionViewModel.addServiceLineToInvoice(invoice, modelContext: modelContext, persistImmediately: false)
                        totalRefreshID += 1
                        hasUnsavedEdits = true
                        onUpdate?()
                    }
                    .buttonStyle(.borderless)
                }
                .font(.subheadline)
                .foregroundStyle(.blue)
            }
        }
        .padding(AppSpacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(AppCornerRadius.l)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .sheet(isPresented: $showInventorySheet) {
            InventorySelectSheet { stones in
                for stone in stones {
                    TransactionViewModel.addStoneToInvoice(stone, invoice: invoice, modelContext: modelContext, persistImmediately: false)
                }
                totalRefreshID += 1
                hasUnsavedEdits = true
                onUpdate?()
                showInventorySheet = false
            }
        }
    }

    /// Removes a line item from the invoice. Restores the linked gemstone to .available or .onMemo before deleting the LineItem only. Gemstones are NEVER deleted.
    private func removeLineItem(_ item: LineItem) {
        withAnimation {
            if let stone = item.gemstone {
                if let originMemo = invoice.originMemo {
                    stone.status = .onMemo
                    stone.memo = originMemo
                } else {
                    stone.status = .available
                    stone.memo = nil
                }
            }
            modelContext.delete(item)
        }
    }
    
    private var invoiceLineItemsTableHeader: some View {
        HStack(alignment: .center, spacing: 0) {
            Text("SKU")
                .frame(width: LineItemColumnLayout.sku, alignment: .leading)
                .padding(.horizontal, 4)
            Text("Description")
                .frame(minWidth: LineItemColumnLayout.descriptionMin, maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
            Text("Carats")
                .frame(width: LineItemColumnLayout.carats, alignment: .trailing)
                .padding(.horizontal, 4)
            Text("Rate")
                .frame(width: LineItemColumnLayout.rate, alignment: .trailing)
                .padding(.horizontal, 4)
            Text("Amount")
                .frame(width: LineItemColumnLayout.amount, alignment: .trailing)
                .padding(.horizontal, 4)
        }
        .font(.caption.bold())
        .foregroundStyle(.secondary)
        .padding(.vertical, 8)
        .background(Color(white: 0.94))
    }
    
    private func deleteInvoice() {
        TransactionViewModel.deleteInvoice(invoice, modelContext: modelContext)
        documentDirtyTracker?.hasUnsavedInvoice = false
        NotificationCenter.default.post(name: .memoOrInvoiceDidSave, object: nil)
        if let onDismiss {
            onDismiss()
        } else {
            NSApp.keyWindow?.close()
        }
    }

    private func markAsPaid() {
        invoice.status = .paid
    }

    private func exportPDF() {
        isGeneratingPDF = true
        pdfError = nil
        PDFService.shared.generatePDF(invoice: invoice) { result in
            isGeneratingPDF = false
            switch result {
            case .success(let url):
                generatedPDFURL = url
            case .failure(let error):
                pdfError = error.localizedDescription
            }
        }
    }
    
    private var displayTitle: String {
        if let ref = invoice.referenceNumber, !ref.isEmpty {
            return "Invoice #\(ref)"
        }
        if let customer = invoice.customer {
            return "Invoice – \(customer.displayName)"
        }
        return "Invoice"
    }
}

// MARK: - PDF export sheet + identifiable URL for sheet(item:)

private struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

private struct PDFExportSheet: View {
    let pdfURL: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("PDF Ready")
                .font(.headline)
            HStack(spacing: 16) {
                Button("Open in Preview") {
                    NSWorkspace.shared.open(pdfURL)
                    dismiss()
                }
                ShareLink(item: pdfURL) {
                    Label("Share…", systemImage: "square.and.arrow.up")
                }
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(minWidth: 320)
    }
}
