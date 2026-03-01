import SwiftUI
import SwiftData

struct MemoDetailView: View {
    let memo: Memo
    var onDelete: (() -> Void)?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedLineItemIDs: Set<PersistentIdentifier> = []
    @State private var createdInvoice: Invoice?
    @State private var showDeleteConfirm = false

    private var selectedOpenItems: [LineItem] {
        memo.openLineItems.filter { selectedLineItemIDs.contains($0.id) }
    }
    private var canReturnOrInvoice: Bool { !selectedOpenItems.isEmpty }
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                // MARK: - Header Card
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(memo.referenceNumber != nil ? "Memo #\(memo.referenceNumber!)" : "Memo")
                            .font(.title2.bold())
                        Spacer()
                        StatusBadge(status: memo.status.rawValue)
                    }
                    
                    if let customer = memo.customer {
                        HStack(alignment: .top) {
                            Image(systemName: "person.crop.circle")
                            VStack(alignment: .leading) {
                                Text(customer.displayName).font(.headline)
                                Text(customer.email ?? "").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.top, 4)
                    }
                    
                    Divider().padding(.vertical, 8)
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Date").font(.caption).foregroundStyle(.secondary)
                            Text(memo.dateAssigned ?? Date(), style: .date)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("Total Value").font(.caption).foregroundStyle(.secondary)
                            Text(memo.totalAmount, format: .currency(code: "USD"))
                                .font(.title3.bold())
                        }
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                
                // MARK: - Line Items Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Items on Memo")
                            .font(.headline)
                        Spacer()
                    }
                    HStack(spacing: 8) {
                        Button("Return Items") { returnSelectedToStock() }
                            .disabled(!canReturnOrInvoice)
                        Button("Convert to Invoice") { convertSelectedToInvoice() }
                            .disabled(!canReturnOrInvoice)
                            .buttonStyle(.borderedProminent)
                        if selectedLineItemIDs.isEmpty {
                            Text("0 selected").font(.caption).foregroundStyle(.tertiary)
                        } else {
                            Text("\(selectedLineItemIDs.count) selected").font(.caption).foregroundStyle(.secondary)
                        }
                        if !selectedLineItemIDs.isEmpty {
                            Button("Clear Selection") { selectedLineItemIDs = [] }
                                .font(.caption)
                                .buttonStyle(.borderless)
                        }
                    }
                    HStack(alignment: .center, spacing: 0) {
                        Color.clear.frame(width: LineItemColumnLayout.check).padding(.horizontal, 4)
                        Text("SKU").frame(width: LineItemColumnLayout.sku, alignment: .leading).padding(.horizontal, 4)
                        Text("Description").frame(minWidth: LineItemColumnLayout.descriptionMin, maxWidth: .infinity, alignment: .leading).padding(.horizontal, 4)
                        Text("Carats").frame(width: LineItemColumnLayout.carats, alignment: .trailing).padding(.horizontal, 4)
                        Text("Rate").frame(width: LineItemColumnLayout.rate, alignment: .trailing).padding(.horizontal, 4)
                        Text("Amount").frame(width: LineItemColumnLayout.amount, alignment: .trailing).padding(.horizontal, 4)
                        Text("Status").frame(width: LineItemColumnLayout.status, alignment: .leading).padding(.horizontal, 4)
                    }
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 4)
                    
                    if memo.lineItems.isEmpty {
                        ContentUnavailableView("No Items", systemImage: "cube.box", description: Text("This memo is empty."))
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(memo.lineItems.sorted(by: { $0.sku < $1.sku }), id: \.id) { item in
                                MemoLineItemRow(
                                    item: item,
                                    isSelected: selectedLineItemIDs.contains(item.id),
                                    canSelect: item.effectiveStatus == .open,
                                    onTap: { if item.effectiveStatus == .open { toggleSelection(item) } }
                                )
                                Divider()
                            }
                        }
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .toolbar {
            ToolbarItem {
                Button(role: .destructive) { showDeleteConfirm = true } label: {
                    Label("Delete", systemImage: "trash")
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
    }
    
    // MARK: - Logic Helpers
    private func toggleSelection(_ item: LineItem) {
        if selectedLineItemIDs.contains(item.id) {
            selectedLineItemIDs.remove(item.id)
        } else {
            selectedLineItemIDs.insert(item.id)
        }
    }
    
    private func convertSelectedToInvoice() {
        guard !selectedOpenItems.isEmpty else { return }
        if let newInvoice = TransactionViewModel.convertMemoToInvoice(memo: memo, selectedLineItems: selectedOpenItems, modelContext: modelContext) {
            createdInvoice = newInvoice
            selectedLineItemIDs.removeAll()
        }
    }
    
    private func returnSelectedToStock() {
        guard !selectedOpenItems.isEmpty else { return }
        TransactionViewModel.returnItemsFromMemo(items: selectedOpenItems, modelContext: modelContext)
        selectedLineItemIDs.removeAll()
    }
    
    private func deleteMemo() {
        TransactionViewModel.returnItemsFromMemo(items: memo.openLineItems, modelContext: modelContext)
        modelContext.delete(memo)
        onDelete?()
        dismiss()
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
                        .foregroundStyle(.tertiary)
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
        case .open: return .secondary       // Grey
        case .returned: return .red         // Red
        case .sold: return .green            // Green
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
            .background(Color.blue.opacity(0.1))
            .foregroundStyle(.blue)
            .cornerRadius(4)
    }
}