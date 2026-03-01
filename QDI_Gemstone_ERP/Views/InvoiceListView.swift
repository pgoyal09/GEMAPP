import SwiftUI
import SwiftData

struct InvoiceListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @Environment(\.documentDirtyTracker) private var documentDirtyTracker
    @Environment(\.navigationGuard) private var navigationGuard
    @State private var viewModel = InvoicesViewModel()
    @State private var selectedInvoiceID: PersistentIdentifier?

    var body: some View {
        VStack(spacing: 0) {
            // Title row
            HStack {
                Text("Invoices")
                    .font(AppTypography.title)
                    .foregroundStyle(AppColors.ink)
                Spacer()
                Button {
                    let invoice = TransactionViewModel.createNewInvoice(modelContext: modelContext)
                    openWindow(id: "invoice", value: invoice.id)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(AppColors.primary)
                }
                .buttonStyle(.plain)
                Button("Open") {
                    openSelectedInvoice()
                }
                .disabled(selectedInvoiceID == nil)
                .keyboardShortcut("o", modifiers: .command)
            }
            .padding()
            if viewModel.invoices.isEmpty {
                ContentUnavailableView(
                    "No Invoices",
                    systemImage: "dollarsign.circle",
                    description: Text("Invoices will appear here when you create them from memos or the transaction editor.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(viewModel.invoices, selection: $selectedInvoiceID) {
                    TableColumn("Invoice #") { inv in
                        Text(inv.referenceNumber ?? "—")
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    TableColumn("Customer") { inv in
                        Text(inv.customer?.displayName ?? "—")
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    TableColumn("Date") { inv in
                        Text(inv.invoiceDate, style: .date)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    TableColumn("Total") { inv in
                        Text(formatTotal(inv))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    TableColumn("Status") { inv in
                        StatusLabel(status: inv.effectiveStatus)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .tableStyle(.bordered(alternatesRowBackgrounds: true))
                .contextMenu(forSelectionType: PersistentIdentifier.self) { items in
                    if !items.isEmpty {
                        Button("Open") {
                            if let id = items.first {
                                openWindow(id: "invoice", value: id)
                            }
                        }
                    }
                } primaryAction: { items in
                    if let id = items.first {
                        openWindow(id: "invoice", value: id)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.shellGradient)
        .onAppear {
            viewModel.load(modelContext: modelContext)
            if let id = selectedInvoiceID, !viewModel.invoices.contains(where: { $0.id == id }) {
                selectedInvoiceID = nil
            }
            navigationGuard?.reportDirty(documentDirtyTracker?.hasUnsavedInvoice ?? false)
        }
        .onReceive(NotificationCenter.default.publisher(for: .memoOrInvoiceDidSave)) { _ in
            viewModel.load(modelContext: modelContext)
        }
        .onChange(of: documentDirtyTracker?.hasUnsavedInvoice ?? false) { _, dirty in
            navigationGuard?.reportDirty(dirty)
        }
        .onDisappear {
            navigationGuard?.reportDirty(false)
        }
    }

    private func openSelectedInvoice() {
        guard let id = selectedInvoiceID else { return }
        openWindow(id: "invoice", value: id)
    }

    private func formatTotal(_ invoice: Invoice) -> String {
        let total = invoice.lineItems.reduce(Decimal(0)) { $0 + $1.amount }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: total as NSDecimalNumber) ?? "$0"
    }
}

// MARK: - Status badge (Paid = green, others = gray)

private struct StatusLabel: View {
    let status: InvoiceStatus

    var body: some View {
        Text(status.rawValue)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(status == .paid ? Color.green : Color.secondary)
    }
}
