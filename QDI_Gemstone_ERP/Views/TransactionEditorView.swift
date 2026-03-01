import SwiftUI
import SwiftData

enum TransactionMode {
    case invoice
    case memo
    case editMemo(Memo)
}

struct TransactionEditorView: View {
    let mode: TransactionMode
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.rfidService) private var rfidService
    
    @State private var viewModel = TransactionViewModel()
    @State private var showInventorySheet = false
    @State private var showAddCustomerSheet = false
    
    @Query(sort: \Customer.lastName) private var customers: [Customer]
    
    private var title: String {
        switch mode {
        case .invoice: return "New Invoice"
        case .memo: return "New Memo"
        case .editMemo: return "Edit Memo"
        }
    }
    
    private var saveButtonLabel: String {
        switch mode {
        case .invoice: return "Save"
        case .memo: return "Create"
        case .editMemo: return "Save"
        }
    }
    
    private var referenceLabel: String {
        switch mode {
        case .invoice: return "Reference"
        case .memo, .editMemo: return "Memo Number"
        }
    }
    
    private var referencePlaceholder: String {
        switch mode {
        case .invoice: return "Optional"
        case .memo, .editMemo: return "1001"
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if let msg = viewModel.lastRFIDMessage {
                HStack {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(AppColors.inkSubtle)
                    Spacer()
                    Button("Dismiss") { viewModel.clearLastRFIDMessage() }
                        .buttonStyle(.borderless)
                }
                .padding(8)
                .background(AppColors.cardElevated)
            }
            AppSurfaceCard(accent: AppColors.accent) { headerSection }
            AppSurfaceCard(accent: AppColors.primary) { lineItemsSection }
            AppSurfaceCard(accent: AppColors.accentPeach) { footerSection }
        }
        .padding(AppSpacing.xl)
        .frame(minWidth: 700, minHeight: 500)
        .background(AppColors.background)
        .sheet(isPresented: $showInventorySheet) {
            InventorySelectSheet { stone in
                viewModel.addStoneFromInventory(stone)
                showInventorySheet = false
            }
        }
        .sheet(isPresented: $showAddCustomerSheet) {
            NavigationStack {
                AddCustomerSheet { newCustomer in
                    viewModel.customer = newCustomer
                }
            }
        }
        .navigationTitle(title)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(saveButtonLabel) {
                    switch mode {
                    case .invoice: saveInvoice()
                    case .memo: saveMemo()
                    case .editMemo(let memo): saveEditedMemo(memo)
                    }
                }
                .disabled(!viewModel.canSave)
            }
        }
        .onAppear {
            switch mode {
            case .editMemo(let memo):
                viewModel.load(memo: memo)
            case .memo:
                if viewModel.referenceNumber.isEmpty {
                    viewModel.referenceNumber = TransactionViewModel.generateNextMemoNumber(modelContext: modelContext)
                }
            case .invoice:
                break
            }
            rfidService?.onTagDiscovered = { [viewModel] tag in
                viewModel.handleScannedTag(tag, modelContext: modelContext)
            }
        }
        .onDisappear {
            rfidService?.onTagDiscovered = nil
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Customer")
                        .font(.caption)
                        .foregroundStyle(AppColors.inkSubtle)
                    HStack(spacing: 8) {
                        Picker("", selection: $viewModel.customer) {
                            Text("Select customer…").tag(nil as Customer?)
                            ForEach(customers, id: \.id) { customer in
                                Text(customer.displayName).tag(customer as Customer?)
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
                VStack(alignment: .leading, spacing: 8) {
                    Text("Date")
                        .font(.caption)
                        .foregroundStyle(AppColors.inkSubtle)
                    DatePicker("", selection: $viewModel.date, displayedComponents: .date)
                        .labelsHidden()
                        .frame(width: 140)
                }
                if case .invoice = mode {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Terms")
                            .font(.caption)
                            .foregroundStyle(AppColors.inkSubtle)
                        Picker("", selection: $viewModel.terms) {
                            Text("Net 30").tag("Net 30")
                            Text("Net 60").tag("Net 60")
                            Text("Due on receipt").tag("Due on receipt")
                            Text("COD").tag("COD")
                        }
                        .pickerStyle(.menu)
                        .frame(width: 140)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text(referenceLabel)
                        .font(.caption)
                        .foregroundStyle(AppColors.inkSubtle)
                    TextField(referencePlaceholder, text: $viewModel.referenceNumber)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                }
            }
        }
    }
    
    private var lineItemsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Line Items")
                    .font(AppTypography.heading)
                Spacer()
            }

            if viewModel.items.isEmpty {
                Text("No line items. Use \"Add Line\" to add from inventory or add a custom line (e.g. Shipping).")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.inkSubtle)
                    .frame(maxWidth: .infinity)
                    .padding(32)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    lineItemHeader
                    Divider()
                    List(Array(viewModel.items.enumerated()), id: \.element.id) { index, item in
                        TransactionLineRowView(
                            item: item,
                            index: index,
                            viewModel: viewModel,
                            formatCurrency: formatCurrency
                        )
                    }
                    .listStyle(.plain)
                    .frame(minHeight: 120)
                }
            }
            HStack(spacing: AppSpacing.m) {
                Button("+ From Inventory") { showInventorySheet = true }
                    .buttonStyle(.borderless)
                Button("+ Brokered Stone") { viewModel.addBrokeredLine() }
                    .buttonStyle(.borderless)
                Button("+ Custom Line") { viewModel.addServiceLine() }
                    .buttonStyle(.borderless)
            }
            .font(.subheadline)
            .foregroundStyle(AppColors.primary)
        }
    }
    
    private var footerSection: some View {
        HStack {
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                HStack {
                    Text("Subtotal")
                        .foregroundStyle(AppColors.inkSubtle)
                    Text(formatCurrency(viewModel.subtotal))
                        .frame(width: 100, alignment: .trailing)
                }
                .font(.subheadline)
                if viewModel.tax > 0 {
                    HStack {
                        Text("Tax")
                            .foregroundStyle(AppColors.inkSubtle)
                        Text(formatCurrency(viewModel.tax))
                            .frame(width: 100, alignment: .trailing)
                    }
                    .font(.subheadline)
                }
                HStack {
                    Text("Total")
                        .fontWeight(.semibold)
                    Text(formatCurrency(viewModel.total))
                        .fontWeight(.semibold)
                        .frame(width: 100, alignment: .trailing)
                }
            }
        }
        .padding(.top, 4)
    }
    
    private var lineItemHeader: some View {
        HStack(alignment: .center, spacing: 8) {
            Text("SKU").frame(width: 80, alignment: .leading)
            Text("Description").frame(minWidth: 180, alignment: .leading)
            Text("Carats").frame(width: 60, alignment: .trailing)
            Text("Rate").frame(width: 80, alignment: .trailing)
            Text("Amount").frame(width: 80, alignment: .trailing)
            Spacer().frame(width: 32)
        }
        .font(.caption)
        .foregroundStyle(AppColors.inkSubtle)
        .padding(.vertical, 4)
    }
    
    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: value as NSDecimalNumber) ?? "$0"
    }
    
    private func saveInvoice() {
        guard let customer = viewModel.customer else { return }
        
        let invoice = Invoice(
            invoiceDate: viewModel.date,
            dueDate: viewModel.dueDate,
            terms: viewModel.terms,
            referenceNumber: viewModel.referenceNumber.isEmpty ? nil : viewModel.referenceNumber,
            notes: viewModel.notes.isEmpty ? nil : viewModel.notes,
            customer: customer
        )
        modelContext.insert(invoice)
        
        for draft in viewModel.lineItems {
            let amount = draft.isService ? draft.rate : draft.rate * Decimal(draft.carats)
            let item = LineItem(
                sku: draft.sku,
                itemDescription: draft.description,
                carats: draft.carats,
                rate: draft.rate,
                amount: amount,
                gemstone: draft.gemstone,
                isService: draft.isService
            )
            modelContext.insert(item)
            item.invoice = invoice
            
            if let stone = draft.gemstone {
                stone.memo = nil
                stone.status = .sold
                logEvent(stone: stone, type: .sold, message: "Sold to \(customer.displayName)", modelContext: modelContext)
            }
        }
        #if DEBUG
        // Safety: Gemstones must NEVER be deleted in invoice flow; only status is updated to .sold.
        let stoneCount = viewModel.lineItems.compactMap(\.gemstone).count
        if stoneCount > 0 {
            print("[Invoice] Saved \(stoneCount) gemstone(s) with status=Sold; no gemstones deleted.")
        }
        #endif
        do {
            try modelContext.save()
            viewModel.reset()
            dismiss()
        } catch {
            print("Failed to save invoice: \(error)")
        }
    }
    
    private func saveMemo() {
        guard let customer = viewModel.customer else { return }
        
        let memo = Memo(
            status: .onMemo,
            dateAssigned: viewModel.date,
            notes: viewModel.notes.isEmpty ? nil : viewModel.notes,
            referenceNumber: viewModel.referenceNumber.isEmpty ? nil : viewModel.referenceNumber,
            customer: customer
        )
        modelContext.insert(memo)
        
        for draft in viewModel.lineItems {
            let amount = draft.isService ? draft.rate : draft.rate * Decimal(draft.carats)
            let item = LineItem(
                sku: draft.sku,
                itemDescription: draft.description,
                carats: draft.carats,
                rate: draft.rate,
                amount: amount,
                gemstone: draft.gemstone,
                isService: draft.isService
            )
            modelContext.insert(item)
            item.memo = memo
            
            if let stone = draft.gemstone {
                stone.memo = memo
                stone.status = .onMemo
                logEvent(stone: stone, type: .sentToCustomer, message: "Sent to \(customer.displayName)", modelContext: modelContext)
            }
        }
        
        do {
            try modelContext.save()
            viewModel.reset()
            dismiss()
        } catch {
            print("Failed to save memo: \(error)")
        }
    }
    
    private func saveEditedMemo(_ memo: Memo) {
        guard let customer = viewModel.customer else { return }
        
        memo.customer = customer
        memo.dateAssigned = viewModel.date
        memo.notes = viewModel.notes.isEmpty ? nil : viewModel.notes
        memo.referenceNumber = viewModel.referenceNumber.isEmpty ? nil : viewModel.referenceNumber
        
        let existingItems = Array(memo.lineItems)
        for existing in existingItems {
            if let stone = existing.gemstone {
                stone.memo = nil
                stone.status = .available
            }
            modelContext.delete(existing)
        }
        
        for draft in viewModel.lineItems {
            let amount = draft.isService ? draft.rate : draft.rate * Decimal(draft.carats)
            let item = LineItem(
                sku: draft.sku,
                itemDescription: draft.description,
                carats: draft.carats,
                rate: draft.rate,
                amount: amount,
                gemstone: draft.gemstone,
                isService: draft.isService
            )
            modelContext.insert(item)
            item.memo = memo
            
            if let stone = draft.gemstone {
                stone.memo = memo
                logEvent(stone: stone, type: .sentToCustomer, message: "Sent to \(customer.displayName)", modelContext: modelContext)
            }
        }
        
        do {
            try modelContext.save()
            viewModel.reset()
            dismiss()
        } catch {
            print("Failed to save memo: \(error)")
        }
    }
}

// MARK: - Line row (shared component; all fields editable for memos and invoices)

struct TransactionLineRowView: View {
    let item: DraftLineItem
    let index: Int
    @Bindable var viewModel: TransactionViewModel
    let formatCurrency: (Decimal) -> String
    
    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(item.displaySku)
                .frame(width: 80, alignment: .leading)
            TextField("Description", text: Binding(
                get: { viewModel.items.indices.contains(index) ? viewModel.items[index].description : "" },
                set: { viewModel.updateDescription(at: index, $0) }
            ))
            .textFieldStyle(.roundedBorder)
            .frame(minWidth: 180, alignment: .leading)
            Group {
                if item.isService {
                    Text("—")
                } else {
                    TextField("Carats", text: Binding(
                        get: {
                            guard viewModel.items.indices.contains(index) else { return "" }
                            let c = viewModel.items[index].carats
                            return c == 0 ? "" : String(format: "%.2f", c)
                        },
                        set: { viewModel.updateCarats(at: index, Double($0) ?? 0) }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                }
            }
            .frame(width: 60, alignment: .trailing)
            Group {
                if item.isService {
                    AmountEditCell(amount: Binding(
                        get: { viewModel.items.indices.contains(index) ? "\(viewModel.items[index].rate)" : "" },
                        set: {
                            if let d = Decimal(string: $0), d >= 0 { viewModel.updateAmount(at: index, d) }
                        }
                    ))
                } else {
                    RateEditCell(rate: Binding(
                        get: { viewModel.items.indices.contains(index) ? "\(viewModel.items[index].rate)" : "" },
                        set: {
                            if let d = Decimal(string: $0), d >= 0 { viewModel.updateRate(at: index, d) }
                        }
                    ))
                }
            }
            .frame(width: 80, alignment: .trailing)
            Text(item.displayAmount)
                .frame(width: 80, alignment: .trailing)
            Button {
                viewModel.removeLine(at: IndexSet(integer: index))
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(AppColors.inkSubtle)
            }
            .buttonStyle(.plain)
            .frame(width: 32)
        }
        .padding(.vertical, 2)
    }
}

/// Editable rate cell for the table
struct RateEditCell: View {
    @Binding var rate: String
    
    var body: some View {
        TextField("Rate", text: $rate)
            .textFieldStyle(.roundedBorder)
            .frame(minWidth: 70)
            .multilineTextAlignment(.trailing)
    }
}

/// Editable amount cell (for custom lines)
struct AmountEditCell: View {
    @Binding var amount: String
    
    var body: some View {
        TextField("Amount", text: $amount)
            .textFieldStyle(.roundedBorder)
            .frame(minWidth: 70)
            .multilineTextAlignment(.trailing)
    }
}
