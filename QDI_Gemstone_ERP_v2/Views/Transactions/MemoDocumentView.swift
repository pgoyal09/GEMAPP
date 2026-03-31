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
    @Query(sort: \Customer.lastName) private var allCustomers: [Customer]

    @State private var selectedItemIDs: Set<PersistentIdentifier> = []
    @State private var showInventorySheet = false
    @State private var showLotSheet = false
    @State private var showAddCustomerSheet = false
    @State private var showDeleteConfirm = false
    @State private var hasUnsavedEdits = false
    @State private var isSaving = false
    @State private var isGeneratingPDF = false
    @State private var toastMessage: String?
    @State private var toastIsError = false
    @State private var totalRefreshID = UUID()
    @State private var showUnsavedAlert = false
    @State private var duplicateWarning: String?

    var body: some View {
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
                            withAnimation { toastMessage = nil }
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
                    Spacer()
                    memoStatusBadge
                }

                HStack(spacing: AppSpacing.hero) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Customer").font(AppTypography.caption).foregroundStyle(AppColors.inkSubtle)
                        HStack {
                            Picker("Customer", selection: Binding(
                                get: { memo.customer },
                                set: { memo.customer = $0; markDirty() }
                            )) {
                                Text("Select…").tag(Customer?.none)
                                ForEach(allCustomers) { c in Text(c.displayName).tag(Customer?.some(c)) }
                            }
                            .labelsHidden()
                            .accessibilityLabel("Select Customer")
                            Button(action: { showAddCustomerSheet = true }) {
                                Image(systemName: "plus.circle").foregroundStyle(AppColors.primary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Add Customer")
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Date").font(AppTypography.caption).foregroundStyle(AppColors.inkSubtle)
                        DatePicker("", selection: Binding(
                            get: { memo.dateAssigned ?? Date() },
                            set: { memo.dateAssigned = $0; markDirty() }
                        ), displayedComponents: .date)
                        .labelsHidden()
                    }
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

    @ViewBuilder
    private var memoStatusBadge: some View {
        let tone: StatusBadge.Tone = switch memo.status {
        case .onMemo: .accent
        case .returned: .warning
        case .sold: .success
        }
        StatusBadge(title: memo.status.rawValue, tone: tone)
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

                        lineItemStatusBadge(item)
                            .frame(width: 70, alignment: .trailing)
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
        HStack(spacing: 8) {
            Button("Single/Pair") { showInventorySheet = true }
            Button("Lot") { showLotSheet = true }
                .help("A group of similar stones sold by total carat weight")
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
        }
        .font(AppTypography.caption)
        .foregroundStyle(AppColors.primary)
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
        let tone: StatusBadge.Tone = switch item.status {
        case .open: .neutral
        case .returned: .warning
        case .sold: .success
        }
        StatusBadge(title: item.status.rawValue, tone: tone)
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
                    dismiss()
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
            Button("Discard", role: .destructive) { dismiss() }
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
        withAnimation { toastMessage = message }
    }
}
