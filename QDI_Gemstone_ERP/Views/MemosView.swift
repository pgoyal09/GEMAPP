import SwiftUI
import SwiftData
import AppKit

struct MemosView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @State private var viewModel = MemosViewModel()
    @State private var selectedMemoID: PersistentIdentifier?

    var body: some View {
        VStack(spacing: 0) {
            // Title row + create button
            HStack {
                Text("Memos")
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                Spacer()
                Button {
                    let memo = TransactionViewModel.createNewMemo(modelContext: modelContext)
                    openWindow(id: "memo", value: memo.id)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(AppColors.primary)
                }
                .buttonStyle(.plain)
                Button("Open") {
                    openSelectedMemo()
                }
                .disabled(selectedMemoID == nil)
                .keyboardShortcut("o", modifiers: .command)
            }
            .padding()
            // Memo list only
            if viewModel.memos.isEmpty {
                ContentUnavailableView(
                    "No Memos",
                    systemImage: "doc.text",
                    description: Text("Create a memo to send stones on consignment.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(viewModel.memos, selection: $selectedMemoID) {
                    TableColumn("Memo #") { memo in
                        Text(memo.referenceNumber ?? "—")
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .width(80)
                    TableColumn("Customer") { memo in
                        Text(memo.customer?.displayName ?? "—")
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .width(min: 140, ideal: 200)
                    TableColumn("Memo Date") { memo in
                        Text(memo.dateAssigned ?? Date(), style: .date)
                    }
                    .width(100)
                    TableColumn("Days Old") { memo in
                        daysOldView(memo)
                    }
                    .width(80)
                    TableColumn("Memo Amount") { memo in
                        memoAmountView(memo)
                    }
                    .width(120)
                    TableColumn("Customer Exposure") { memo in
                        if let customer = memo.customer {
                            Text(customer.openExposure, format: .currency(code: "USD"))
                                .monospacedDigit()
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("—")
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .width(130)
                }
                .tableStyle(.bordered(alternatesRowBackgrounds: true))
                .contextMenu(forSelectionType: PersistentIdentifier.self) { items in
                    if !items.isEmpty {
                        Button("Open") {
                            if let id = items.first {
                                openWindow(id: "memo", value: id)
                            }
                        }
                    }
                } primaryAction: { items in
                    if let id = items.first {
                        openWindow(id: "memo", value: id)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            viewModel.load(modelContext: modelContext)
            if let id = selectedMemoID, !viewModel.memos.contains(where: { $0.id == id }) {
                selectedMemoID = nil
            }
        }
    }

    private func memoAmountView(_ memo: Memo) -> some View {
        Group {
            if memo.isClosed {
                Text("Closed")
                    .foregroundStyle(.secondary)
            } else {
                Text(memo.openMemoAmount, format: .currency(code: "USD"))
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func daysOldView(_ memo: Memo) -> some View {
        let days = daysSince(memo.dateAssigned ?? Date())
        let label = days == 0 ? "0d" : "\(days)d"
        return Text(label)
            .fontWeight(.medium)
            .foregroundStyle(daysOldColor(days))
    }

    private func daysSince(_ date: Date) -> Int {
        Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
    }

    private func daysOldColor(_ days: Int) -> Color {
        switch days {
        case 0...7: return Color.green
        case 8...14: return Color(red: 0.85, green: 0.65, blue: 0.13)  // yellow/amber
        case 15...30: return Color(red: 0.9, green: 0.45, blue: 0.2)    // dark orange
        default: return Color.red
        }
    }

    private func openSelectedMemo() {
        guard let id = selectedMemoID else { return }
        openWindow(id: "memo", value: id)
    }

    private func memoDisplayTitle(_ memo: Memo) -> String {
        let ref = memo.referenceNumber.map { "#\($0) " } ?? ""
        let name = memo.customer?.displayName ?? "Unknown"
        return "Memo \(ref)– \(name)"
    }
}

// MARK: - Full Memo Document View (QuickBooks-like) - used in MemoWindowView

struct MemoDocumentView: View {
    let memo: Memo
    var onDelete: (() -> Void)?
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Customer.lastName) private var customers: [Customer]
    @State private var selectedLineItemIDs: Set<PersistentIdentifier> = []
    @State private var createdInvoice: Invoice?
    @State private var showDeleteConfirm = false
    @State private var showInventorySheet = false
    @State private var showAddCustomerSheet = false
    @State private var showLeaveWithoutSavingAlert = false
    @State private var totalRefreshID = 0
    @State private var hasUnsavedEdits = false

    private var isDirty: Bool { modelContext.hasChanges || hasUnsavedEdits }

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
        .background(Color(white: 0.98))
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    if isDirty {
                        showLeaveWithoutSavingAlert = true
                    } else {
                        modelContext.rollback()
                        NSApp.keyWindow?.close()
                    }
                }
                .keyboardShortcut(.cancelAction)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    do {
                        try modelContext.save()
                        hasUnsavedEdits = false
                    } catch {
                        // TODO: show error
                    }
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
        .sheet(isPresented: $showAddCustomerSheet) {
            NavigationStack {
                AddCustomerSheet { newCustomer in
                    memo.customer = newCustomer
                    hasUnsavedEdits = true
                }
            }
        }
        .sheet(item: $createdInvoice) { invoice in
            NavigationStack {
                InvoiceDetailView(invoice: invoice)
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
                NSApp.keyWindow?.close()
            }
        }
        .alert("Leave without saving?", isPresented: $showLeaveWithoutSavingAlert) {
            Button("Keep Editing", role: .cancel) {}
            Button("Discard", role: .destructive) {
                modelContext.rollback()
                NSApp.keyWindow?.close()
            }
        } message: {
            Text("Your changes will not be saved.")
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: AppSpacing.s) {
                    Text("MEMO")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    if isCreateMode {
                        TextField("Memo #", text: Binding(
                        get: { memo.referenceNumber ?? "" },
                        set: { memo.referenceNumber = $0.isEmpty ? nil : $0; hasUnsavedEdits = true }
                        ))
                        .font(.title)
                        .fontWeight(.bold)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 140)
                    } else {
                        Text(memo.referenceNumber.map { "#\($0)" } ?? "Memo")
                            .font(.title)
                            .fontWeight(.bold)
                    }
                }
                Spacer()
                StatusBadge(status: memo.status.rawValue)
            }
            if isCreateMode {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Customer")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                            get: { memo.dateAssigned ?? Date() },
                            set: { memo.dateAssigned = $0; hasUnsavedEdits = true }
                        ), displayedComponents: .date)
                        .labelsHidden()
                    } else {
                        Text(memo.dateAssigned ?? Date(), style: .date)
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

    private var lineItemsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            HStack {
                Text("Line Items")
                    .font(.headline)
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
                        .foregroundStyle(.tertiary)
                } else {
                    Text("\(selectedLineItemIDs.count) selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !selectedLineItemIDs.isEmpty {
                    Button("Clear Selection") { selectedLineItemIDs = [] }
                        .font(.caption)
                        .buttonStyle(.borderless)
                }
            }
            lineItemsTableHeader
            Divider()
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
                        Divider()
                    }
                }
            }
            HStack(spacing: AppSpacing.m) {
                Button("+ From Inventory") { showInventorySheet = true }
                    .buttonStyle(.borderless)
                Button("+ Brokered Stone") {
                    TransactionViewModel.addBrokeredLineToMemo(memo, modelContext: modelContext, persistImmediately: false)
                    totalRefreshID += 1
                    hasUnsavedEdits = true
                }
                .buttonStyle(.borderless)
                Button("+ Custom Line") {
                    TransactionViewModel.addServiceLineToMemo(memo, modelContext: modelContext, persistImmediately: false)
                    totalRefreshID += 1
                    hasUnsavedEdits = true
                }
                .buttonStyle(.borderless)
            }
            .font(.subheadline)
            .foregroundStyle(.blue)
        }
        .padding(AppSpacing.l)
        .background(Color.white)
        .cornerRadius(AppCornerRadius.l)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    private var lineItemsTableHeader: some View {
        HStack(alignment: .center, spacing: 0) {
            Color.clear
                .frame(width: LineItemColumnLayout.check)
                .padding(.horizontal, 4)
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
            Text("Status")
                .frame(width: LineItemColumnLayout.status, alignment: .leading)
                .padding(.horizontal, 4)
        }
        .font(.caption.bold())
        .foregroundStyle(.secondary)
        .padding(.vertical, 8)
        .background(Color(white: 0.94))
    }

    private var totalSection: some View {
        HStack {
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("Total Value")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(memo.openMemoAmount, format: .currency(code: "USD"))
                    .font(.title2.bold())
            }
            .id(totalRefreshID)
        }
        .padding(AppSpacing.l)
    }

    private func notesSection(_ notes: String) -> some View {
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
            createdInvoice = inv
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
        TransactionViewModel.returnItemsFromMemo(items: memo.openLineItems, modelContext: modelContext)
        modelContext.delete(memo)
        try? modelContext.save()
        onDelete?()
        NSApp.keyWindow?.close()
    }
}
