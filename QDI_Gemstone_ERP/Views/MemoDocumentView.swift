import SwiftUI
import SwiftData
import AppKit

// MARK: - Full Memo Document View (QuickBooks-like) - used in MemoWindowView

struct MemoDocumentView: View {
    let memo: Memo
    var onDelete: (() -> Void)?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @Environment(\.documentDirtyTracker) private var documentDirtyTracker
    @Query(sort: \Customer.lastName) private var customers: [Customer]
    @State private var selectedLineItemIDs: Set<PersistentIdentifier> = []
    @State private var showDeleteConfirm = false
    @State private var showInventorySheet = false
    @State private var showLotSheet = false
    @State private var showAddCustomerSheet = false
    @State private var showLeaveWithoutSavingAlert = false
    @State private var totalRefreshID = 0
    @State private var hasUnsavedEdits = false
    @State private var hostWindow: NSWindow?
    @State private var showMissingCustomerAlert = false

    private var isDirty: Bool { modelContext.hasChanges || hasUnsavedEdits }

    private func closeWindow() {
        hostWindow?.close()
    }

    private var isCreateMode: Bool { memo.customer == nil }
    private var selectedOpenItems: [LineItem] {
        memo.openLineItems.filter { selectedLineItemIDs.contains($0.id) }
    }
    private var canReturnOrInvoice: Bool { !selectedOpenItems.isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                headerSection
                lineItemsSection
                totalSection
                if let notes = memo.notes, !notes.isEmpty {
                    notesSection(notes)
                }
            }
            .padding(AppSpacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minWidth: 480)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    if isDirty {
                        showLeaveWithoutSavingAlert = true
                    } else {
                        modelContext.rollback()
                        closeWindow()
                    }
                }
                .keyboardShortcut(.cancelAction)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    _ = performSave()
                }
                .keyboardShortcut(.defaultAction)
            }
            ToolbarItem(placement: .destructiveAction) {
                Button(role: .destructive) { showDeleteConfirm = true } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .sheet(isPresented: $showInventorySheet) {
            InventorySelectSheet { stones in
                for stone in stones {
                    TransactionViewModel.addStoneToMemo(stone, memo: memo, modelContext: modelContext, persistImmediately: false)
                }
                totalRefreshID += 1
                hasUnsavedEdits = true
                showInventorySheet = false
            }
        }
        .sheet(isPresented: $showLotSheet) {
            LotSelectSheet { lot, carats in
                TransactionViewModel.addLotToMemo(lot, carats: carats, memo: memo, modelContext: modelContext, persistImmediately: false)
                totalRefreshID += 1
                hasUnsavedEdits = true
            }
        }
        .sheet(isPresented: $showAddCustomerSheet) {
            NavigationStack {
                CustomerFormSheet(mode: .add) { newCustomer in
                    memo.customer = newCustomer
                    hasUnsavedEdits = true
                }
            }
        }
        .alert("Delete Memo?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) { deleteMemo() }
        } message: {
            Text("Items will be returned to 'Available' status.")
        }
        .onExitCommand {
            if isDirty {
                showLeaveWithoutSavingAlert = true
            } else {
                modelContext.rollback()
                closeWindow()
            }
        }
        .alert("Leave without saving?", isPresented: $showLeaveWithoutSavingAlert) {
            Button("Keep Editing", role: .cancel) {}
            Button("Save and Close") { saveAndClose() }
            Button("Discard edits and leave", role: .destructive) {
                modelContext.rollback()
                documentDirtyTracker?.hasUnsavedMemo = false
                closeWindow()
            }
        } message: {
            Text("Your changes will not be saved.")
        }
        .onChange(of: isDirty) { _, dirty in
            documentDirtyTracker?.hasUnsavedMemo = dirty
        }
        .onAppear {
            hostWindow = NSApp.keyWindow
            documentDirtyTracker?.hasUnsavedMemo = isDirty
            documentDirtyTracker?.onSaveAndClose = { saveAndClose() }
        }
        .onDisappear {
            documentDirtyTracker?.hasUnsavedMemo = false
            documentDirtyTracker?.onSaveAndClose = nil
        }
        .alert("Customer Required", isPresented: $showMissingCustomerAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please select a customer before saving.")
        }
    }

    private func performSave() -> Bool {
        guard memo.customer != nil else {
            showMissingCustomerAlert = true
            return false
        }
        do {
            try modelContext.save()
            hasUnsavedEdits = false
            NotificationCenter.default.post(name: .memoOrInvoiceDidSave, object: nil)
            return true
        } catch {
            return false
        }
    }

    private func saveAndClose() {
        guard performSave() else { return }
        documentDirtyTracker?.hasUnsavedMemo = false
        closeWindow()
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: AppSpacing.s) {
                    Text("MEMO")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.5)
                        .foregroundStyle(AppColors.inkSubtle)
                    if isCreateMode {
                        TextField("Memo #", text: Binding(
                        get: { memo.referenceNumber ?? "" },
                        set: { memo.referenceNumber = $0.isEmpty ? nil : $0; hasUnsavedEdits = true }
                        ))
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(AppColors.ink)
                        .textFieldStyle(.plain)
                        .glassField()
                        .frame(width: 140)
                    } else {
                        Text(memo.referenceNumber.map { "#\($0)" } ?? "Memo")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(AppColors.ink)
                    }
                }
                Spacer()
                StatusBadge(status: memo.status.rawValue)
            }
            if isCreateMode {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Customer")
                        .font(.caption)
                        .foregroundStyle(AppColors.inkMuted)
                    HStack(spacing: 8) {
                        Picker("", selection: Binding(
                            get: { memo.customer },
                            set: { memo.customer = $0; hasUnsavedEdits = true }
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
            } else if let customer = memo.customer {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Customer")
                        .font(.caption)
                        .foregroundStyle(AppColors.inkMuted)
                    Text(customer.displayName)
                        .font(.headline)
                        .foregroundStyle(AppColors.ink)
                    if let email = customer.email, !email.isEmpty {
                        Text(email)
                            .font(.caption)
                            .foregroundStyle(AppColors.inkMuted)
                    }
                    if let addr = customer.formattedAddress {
                        Text(addr).captionLabel()
                    }
                }
            }
            HStack(spacing: AppSpacing.xl) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Date")
                        .font(.caption)
                        .foregroundStyle(AppColors.inkMuted)
                    if isCreateMode {
                        DatePicker("", selection: Binding(
                            get: { memo.dateAssigned ?? Date() },
                            set: { memo.dateAssigned = $0; hasUnsavedEdits = true }
                        ), displayedComponents: .date)
                        .labelsHidden()
                    } else {
                        Text(memo.dateAssigned ?? Date(), style: .date)
                            .foregroundStyle(AppColors.ink)
                    }
                }
            }
        }
        .padding(AppSpacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .heroGlass(radius: AppCornerRadius.l)
    }

    private var lineItemsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            HStack {
                Text("Line Items")
                    .font(.headline)
                    .foregroundStyle(AppColors.ink)
                Spacer()
            }
            HStack(spacing: AppSpacing.s) {
                Button("Return Items") { returnSelectedToStock() }
                    .disabled(!canReturnOrInvoice)
                    .buttonStyle(.bordered)
                Button("Convert to Invoice") { convertSelectedToInvoice() }
                    .disabled(!canReturnOrInvoice)
                    .buttonStyle(.borderedProminent)
                if selectedLineItemIDs.isEmpty {
                    Text("0 selected")
                        .font(.caption)
                        .foregroundStyle(AppColors.inkSubtle)
                } else {
                    Text("\(selectedLineItemIDs.count) selected")
                        .font(.caption)
                        .foregroundStyle(AppColors.inkMuted)
                }
                if !selectedLineItemIDs.isEmpty {
                    Button("Clear Selection") { selectedLineItemIDs = [] }
                        .font(.caption)
                        .buttonStyle(.borderless)
                }
            }
            lineItemsTableHeader
            Divider().overlay(AppColors.cardStroke)
            if memo.lineItems.isEmpty {
                ContentUnavailableView("No Items", systemImage: "cube.box", description: Text("This memo has no items."))
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(memo.lineItems.sorted(by: { $0.sku < $1.sku }), id: \.id) { item in
                        MemoLineItemRow(
                            item: item,
                            isSelected: selectedLineItemIDs.contains(item.id),
                            canSelect: item.effectiveStatus == .open,
                            persistOnEdit: false,
                            onUpdate: { totalRefreshID += 1; hasUnsavedEdits = true },
                            onTap: {
                                if item.effectiveStatus == .open { toggleSelection(item) }
                            }
                        )
                        Divider().overlay(AppColors.cardStroke)
                    }
                }
            }
            HStack(spacing: AppSpacing.s) {
                PillActionButton("Add Single/Pair", icon: "diamond") { showInventorySheet = true }
                PillActionButton("Add Lot", icon: "cube.box") { showLotSheet = true }
                PillActionButton("Brokered Stone", icon: "arrow.left.arrow.right") {
                    TransactionViewModel.addBrokeredLineToMemo(memo, modelContext: modelContext, persistImmediately: false)
                    totalRefreshID += 1
                    hasUnsavedEdits = true
                }
                PillActionButton("Custom Line", icon: "plus.square") {
                    TransactionViewModel.addServiceLineToMemo(memo, modelContext: modelContext, persistImmediately: false)
                    totalRefreshID += 1
                    hasUnsavedEdits = true
                }
            }
        }
        .padding(AppSpacing.l)
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.l, style: .continuous)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCornerRadius.l, style: .continuous)
                        .strokeBorder(AppColors.cardStroke, lineWidth: 1)
                )
        )
    }

    private var lineItemsTableHeader: some View {
        HStack(alignment: .center, spacing: 0) {
            Color.clear
                .frame(width: LineItemColumnLayout.check)
                .padding(.horizontal, 4)
            Text("SKU")
                .frame(width: LineItemColumnLayout.sku, alignment: .leading)
                .padding(.horizontal, 4)
            Text("STONE TYPE")
                .frame(width: LineItemColumnLayout.stoneType, alignment: .leading)
                .padding(.horizontal, 4)
            Text("DESCRIPTION")
                .frame(minWidth: LineItemColumnLayout.descriptionMin, maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
            Text("CARATS")
                .frame(width: LineItemColumnLayout.carats, alignment: .trailing)
                .padding(.horizontal, 4)
            Text("RATE")
                .frame(width: LineItemColumnLayout.rate, alignment: .trailing)
                .padding(.horizontal, 4)
            Text("AMOUNT")
                .frame(width: LineItemColumnLayout.amount, alignment: .trailing)
                .padding(.horizontal, 4)
            Text("STATUS")
                .frame(width: LineItemColumnLayout.status, alignment: .leading)
                .padding(.horizontal, 4)
        }
        .font(.system(size: 11, weight: .semibold))
        .tracking(0.5)
        .foregroundStyle(AppColors.inkSubtle)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.03))
    }

    private var totalSection: some View {
        HStack {
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("Total Value")
                    .font(.caption)
                    .foregroundStyle(AppColors.inkMuted)
                Text(memo.openMemoAmount, format: .currency(code: "USD"))
                    .font(.title2.bold())
                    .foregroundStyle(AppColors.ink)
            }
            .id(totalRefreshID)
        }
        .padding(AppSpacing.l)
    }

    private func notesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Text("Notes")
                .font(.caption)
                .foregroundStyle(AppColors.inkMuted)
            Text(notes)
                .font(.subheadline)
                .foregroundStyle(AppColors.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.l)
    }

    private func toggleSelection(_ item: LineItem) {
        if selectedLineItemIDs.contains(item.id) {
            selectedLineItemIDs.remove(item.id)
        } else {
            selectedLineItemIDs.insert(item.id)
        }
    }

    private func convertSelectedToInvoice() {
        guard !selectedOpenItems.isEmpty else { return }
        if let inv = TransactionViewModel.convertMemoToInvoice(memo: memo, selectedLineItems: selectedOpenItems, modelContext: modelContext) {
            openWindow(id: "invoice", value: inv.id)
            selectedLineItemIDs.removeAll()
            totalRefreshID += 1
            hasUnsavedEdits = true
        }
    }

    private func returnSelectedToStock() {
        guard !selectedOpenItems.isEmpty else { return }
        TransactionViewModel.returnItemsFromMemo(items: selectedOpenItems, modelContext: modelContext)
        selectedLineItemIDs.removeAll()
        totalRefreshID += 1
        hasUnsavedEdits = true
    }

    private func deleteMemo() {
        let itemsToReturn = Array(memo.openLineItems)
        TransactionViewModel.returnItemsFromMemo(items: itemsToReturn, modelContext: modelContext)
        modelContext.delete(memo)
        do {
            try modelContext.save()
        } catch {
            return
        }
        documentDirtyTracker?.hasUnsavedMemo = false
        NSApp.keyWindow?.close()
        NotificationCenter.default.post(name: .memoOrInvoiceDidSave, object: nil)
        onDelete?()
    }
}

// MARK: - Subviews (editable line items; totals recompute from lineItems)
struct MemoLineItemRow: View {
    let item: LineItem
    let isSelected: Bool
    var canSelect: Bool = true
    var persistOnEdit: Bool = true
    var onUpdate: (() -> Void)? = nil
    let onTap: () -> Void
    
    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Group {
                if canSelect {
                    Toggle("", isOn: Binding(
                        get: { isSelected },
                        set: { _ in onTap() }
                    ))
                    .toggleStyle(.checkbox)
                    .labelsHidden()
                } else {
                    Image(systemName: "square.dashed")
                        .foregroundStyle(AppColors.inkSubtle)
                }
            }
            .frame(width: LineItemColumnLayout.check, alignment: .leading)
            .padding(.horizontal, 4)
            
            EditableLineItemRow(item: item, persistOnEdit: persistOnEdit, onUpdate: onUpdate)
            
            Text(item.effectiveStatus.rawValue)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(statusColor)
                .frame(width: LineItemColumnLayout.status, alignment: .leading)
                .padding(.horizontal, 4)
        }
        .contentShape(Rectangle())
        .onTapGesture { if canSelect { onTap() } }
    }
    
    private var statusColor: Color {
        switch item.effectiveStatus {
        case .open: return AppColors.inkMuted
        case .returned: return AppColors.danger
        case .sold: return AppColors.success
        }
    }
}

struct StatusBadge: View {
    let status: String
    var body: some View {
        Text(status.uppercased())
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(AppColors.primary.opacity(0.15))
            .foregroundStyle(AppColors.primary)
            .cornerRadius(4)
    }
}
