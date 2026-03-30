import SwiftUI
import SwiftData

enum TransactionMode {
    case invoice
    case memo
    case editMemo(Memo)
}

struct TransactionEditorView: View {
    let mode: TransactionMode
    
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @Environment(\.rfidService) private var rfidService
    
    @State var viewModel = TransactionViewModel()
    @State var showInventorySheet = false
    @State var showAddCustomerSheet = false
    @State var saveErrorMessage: String?
    
    @Query(sort: \Customer.lastName) var customers: [Customer]
    
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
            InventorySelectSheet { stones in
                for stone in stones {
                    viewModel.addStoneFromInventory(stone)
                }
                showInventorySheet = false
            }
        }
        .sheet(isPresented: $showAddCustomerSheet) {
            NavigationStack {
                CustomerFormSheet(mode: .add) { newCustomer in
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
        .alert("Save Error", isPresented: Binding(get: { saveErrorMessage != nil }, set: { if !$0 { saveErrorMessage = nil } })) {
            Button("OK", role: .cancel) { saveErrorMessage = nil }
        } message: {
            Text(saveErrorMessage ?? "An unknown error occurred.")
        }
    }
}

// MARK: - Line row (shared component; all fields editable for memos and invoices)

struct TransactionLineRowView: View {
    let item: DraftLineItem
    let index: Int
    @Bindable var viewModel: TransactionViewModel
    
    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(item.displaySku)
                .frame(width: 80, alignment: .leading)
            if item.isBrokered {
                Picker("", selection: Binding(
                    get: { viewModel.items.indices.contains(index) ? viewModel.items[index].brokeredStoneType : "" },
                    set: { viewModel.updateBrokeredStoneType(at: index, $0) }
                )) {
                    Text("Type…").tag("").foregroundStyle(AppColors.inkSubtle)
                    ForEach(StoneType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 90)
            }
            TextField("Description", text: Binding(
                get: { viewModel.items.indices.contains(index) ? viewModel.items[index].description : "" },
                set: { viewModel.updateDescription(at: index, $0) }
            ))
            .textFieldStyle(.plain)
            .glassField()
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
                    .textFieldStyle(.plain)
                    .glassField()
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
            .textFieldStyle(.plain)
            .glassField()
            .frame(minWidth: 70)
            .multilineTextAlignment(.trailing)
    }
}

/// Editable amount cell (for custom lines)
struct AmountEditCell: View {
    @Binding var amount: String
    
    var body: some View {
        TextField("Amount", text: $amount)
            .textFieldStyle(.plain)
            .glassField()
            .frame(minWidth: 70)
            .multilineTextAlignment(.trailing)
    }
}
