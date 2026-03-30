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
    @State private var showLotSheet = false
    @State private var showAddCustomerSheet = false
    @State private var showLeaveWithoutSavingAlert = false
    @State private var showDeleteConfirm = false
    @State private var totalRefreshID = 0
    @State private var hasUnsavedEdits = false
    @State private var hostWindow: NSWindow?
    @State private var showMissingCustomerAlert = false
    @State private var isEditingEnabled: Bool = false
    @State private var showEditConfirmAlert: Bool = false

    private var isDirty: Bool { modelContext.hasChanges || hasUnsavedEdits }

    private func closeWindow() {
        if let onDismiss { onDismiss() } else { hostWindow?.close() }
    }

    /// Dismisses the view: when onDismiss is set (sheet), clears parent binding; else closes window.
    private func performDismiss() {
        modelContext.rollback()
        documentDirtyTracker?.hasUnsavedInvoice = false
        closeWindow()
    }

    /// Saves the invoice (persisting converted memo items) without closing. Returns true on success.
    @discardableResult
    private func performSave() -> Bool {
        guard invoice.customer != nil else {
            showMissingCustomerAlert = true
            return false
        }
        TransactionViewModel.markConvertedLineItemsAsSold(invoice: invoice, modelContext: modelContext)
        do {
            try modelContext.save()
            hasUnsavedEdits = false
            onUpdate?()
            NotificationCenter.default.post(name: .memoOrInvoiceDidSave, object: nil)
            return true
        } catch {
            pdfError = error.localizedDescription
            return false
        }
    }

    /// Saves the invoice (including marking converted memo items sold) and closes without rollback.
    private func saveAndClose() {
        guard performSave() else { return }
        documentDirtyTracker?.hasUnsavedInvoice = false
        closeWindow()
    }

    private var isCreateMode: Bool { invoice.customer == nil }
    private var editingAllowed: Bool { isCreateMode || isEditingEnabled }
    private func invoiceStatusColor(_ status: InvoiceStatus) -> Color {
        switch status {
        case .paid:  return AppColors.success
        case .void:  return AppColors.danger
        case .draft: return AppColors.inkMuted
        case .sent:  return AppColors.warning
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: AppSpacing.s) {
                    Text("INVOICE")
                        .font(AppTypography.sectionLabel)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.white.opacity(0.40))
                    Text(displayTitle)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(AppColors.ink)
                }
                Spacer()
                AppStatusBadge(
                    title: invoice.effectiveStatus.rawValue,
                    tone: invoiceStatusTone(invoice.effectiveStatus)
                )
            }
            if editingAllowed {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Bill To")
                        .captionLabel()
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
                        .captionLabel()
                    Text(customer.displayName)
                        .font(.headline)
                        .foregroundStyle(AppColors.ink)
                    if let email = customer.email, !email.isEmpty {
                        Text(email)
                            .captionLabel()
                    }
                    if let addr = customer.formattedAddress {
                        Text(addr)
                            .captionLabel()
                    }
                }
            }
            HStack(spacing: AppSpacing.xl) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Date")
                        .captionLabel()
                    if editingAllowed {
                        DatePicker("", selection: Binding(
                            get: { invoice.invoiceDate },
                            set: { invoice.invoiceDate = $0; hasUnsavedEdits = true; onUpdate?() }
                        ), displayedComponents: .date)
                        .labelsHidden()
                    } else {
                        Text(invoice.invoiceDate, style: .date)
                            .foregroundStyle(AppColors.ink)
                    }
                }
                if editingAllowed {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Terms")
                            .captionLabel()
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
                            .captionLabel()
                        Text(due, style: .date)
                            .foregroundStyle(AppColors.ink)
                    }
                }
                if let terms = invoice.terms, !terms.isEmpty, !editingAllowed {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Terms")
                            .captionLabel()
                        Text(terms)
                            .foregroundStyle(AppColors.ink)
                    }
                }
            }
        }
        .padding(AppSpacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .heroGlass(radius: AppCornerRadius.l)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppSpacing.xl) {
                headerSection

                // Line items
                lineItemsSection
                
                // Totals
                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Total")
                            .captionLabel()
                        Text(invoice.lineItems.reduce(Decimal(0)) { $0 + $1.amount }.asCurrency)
                            .font(.title2.bold())
                            .foregroundStyle(AppColors.ink)
                    }
                    .id(totalRefreshID)
                }
                .padding(AppSpacing.l)
                
                if let notes = invoice.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: AppSpacing.s) {
                        Text("Notes")
                            .captionLabel()
                        Text(notes)
                            .font(.subheadline)
                            .foregroundStyle(AppColors.ink)
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
        .background(Color.clear)
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
                    performSave()
                }
                .keyboardShortcut(.defaultAction)
            }
            ToolbarItem(placement: .primaryAction) {
                if !editingAllowed {
                    Button("Edit Invoice") {
                        showEditConfirmAlert = true
                    }
                    .buttonStyle(GradientButtonStyle())
                }
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
        .alert("Edit Invoice?", isPresented: $showEditConfirmAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Edit") { isEditingEnabled = true }
        } message: {
            Text("Making changes to a finalized invoice will mark it as unsaved. Are you sure?")
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
                CustomerFormSheet(mode: .add) { newCustomer in
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
            Button("Save and Close") { saveAndClose() }
            Button("Discard edits and leave", role: .destructive) {
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
            hostWindow = NSApp.keyWindow
            documentDirtyTracker?.hasUnsavedInvoice = isDirty
            documentDirtyTracker?.onSaveAndClose = { saveAndClose() }
        }
        .onDisappear {
            documentDirtyTracker?.hasUnsavedInvoice = false
            documentDirtyTracker?.onSaveAndClose = nil
        }
        .alert("Customer Required", isPresented: $showMissingCustomerAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please select a customer before saving.")
        }
    }

    private func invoiceStatusTone(_ status: InvoiceStatus) -> AppStatusBadge.Tone {
        switch status {
        case .paid:  return .success
        case .void:  return .danger
        case .draft: return .neutral
        case .sent:  return .warning
        }
    }

    private var lineItemsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            Text("Line Items")
                .font(.headline)
                .foregroundStyle(AppColors.ink)
            if invoice.lineItems.isEmpty {
                Text("No line items")
                    .foregroundStyle(Color.white.opacity(0.40))
                    .padding()
            } else {
                LazyVStack(spacing: 0) {
                    invoiceLineItemsTableHeader
                    Divider().overlay(AppColors.cardStroke)
                    ForEach(invoice.lineItems.sorted(by: { $0.displaySku < $1.displaySku }), id: \.id) { item in
                        EditableLineItemRow(item: item, persistOnEdit: false, onUpdate: { totalRefreshID += 1; hasUnsavedEdits = true; onUpdate?() })
                            .contextMenu {
                                Button("Delete", role: .destructive) {
                                    removeLineItem(item)
                                    totalRefreshID += 1
                                    hasUnsavedEdits = true
                                }
                            }
                        Divider().overlay(AppColors.cardStroke)
                    }
                }
            }
            if editingAllowed && invoice.effectiveStatus != .paid && invoice.effectiveStatus != .void {
                HStack(spacing: AppSpacing.s) {
                    PillActionButton("Add Single/Pair", icon: "diamond") { showInventorySheet = true }
                    PillActionButton("Add Lot", icon: "cube.box") { showLotSheet = true }
                    PillActionButton("Brokered Stone", icon: "arrow.left.arrow.right") {
                        TransactionViewModel.addBrokeredLineToInvoice(invoice, modelContext: modelContext, persistImmediately: false)
                        totalRefreshID += 1
                        hasUnsavedEdits = true
                        onUpdate?()
                    }
                    PillActionButton("Custom Line", icon: "plus.square") {
                        TransactionViewModel.addServiceLineToInvoice(invoice, modelContext: modelContext, persistImmediately: false)
                        totalRefreshID += 1
                        hasUnsavedEdits = true
                        onUpdate?()
                    }
                }
            }
        }
        .padding(AppSpacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.l, style: .continuous)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCornerRadius.l, style: .continuous)
                        .strokeBorder(AppColors.cardStroke, lineWidth: 1)
                )
        )
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
        .sheet(isPresented: $showLotSheet) {
            LotSelectSheet { lot, carats in
                TransactionViewModel.addLotToInvoice(lot, carats: carats, invoice: invoice, modelContext: modelContext, persistImmediately: false)
                totalRefreshID += 1
                hasUnsavedEdits = true
                onUpdate?()
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
            Text("Stone Type")
                .frame(width: LineItemColumnLayout.stoneType, alignment: .leading)
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
        .font(AppTypography.sectionLabel)
        .textCase(.uppercase)
        .foregroundStyle(Color.white.opacity(0.40))
        .padding(.vertical, 8)
        .background(AppColors.cardElevated)
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
                .foregroundStyle(AppColors.ink)
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
