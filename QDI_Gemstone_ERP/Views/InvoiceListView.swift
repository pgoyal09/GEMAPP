import SwiftUI
import SwiftData

struct InvoiceListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @Environment(\.documentDirtyTracker) private var documentDirtyTracker
    @Environment(\.navigationGuard) private var navigationGuard
    @Query(sort: \Invoice.invoiceDate, order: .reverse) private var invoices: [Invoice]
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
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 13, weight: .medium))
                        Text("New Invoice")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(AppColors.primaryGradient, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: AppColors.primary.opacity(0.20), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("n", modifiers: .command)
                Button("Open") {
                    openSelectedInvoice()
                }
                .foregroundStyle(AppColors.primary)
                .disabled(selectedInvoiceID == nil)
                .keyboardShortcut("o", modifiers: .command)
            }
            .padding()
            if invoices.isEmpty {
                ContentUnavailableView(
                    "No Invoices",
                    systemImage: "dollarsign.circle",
                    description: Text("Invoices will appear here when you create them from memos or the transaction editor.")
                )
                .foregroundStyle(Color.white.opacity(0.40))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                GlassCard(padding: 0) {
                    VStack(spacing: 0) {
                        AppTableHeader(columns: [
                            .init("INVOICE #", width: 120),
                            .init("CUSTOMER"),
                            .init("DATE", width: 100),
                            .init("TOTAL", width: 110, alignment: .trailing),
                            .init("STATUS", width: 80)
                        ])
                        Divider().overlay(AppColors.cardStroke)
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(invoices) { inv in
                                    AppTableHoverRow(
                                        isSelected: selectedInvoiceID == inv.id,
                                        onTap: {
                                            selectedInvoiceID = inv.id
                                            openWindow(id: "invoice", value: inv.id)
                                        }
                                    ) {
                                        HStack(spacing: 0) {
                                            Text(inv.referenceNumber ?? "—")
                                                .font(.system(size: 13, design: .monospaced))
                                                .foregroundStyle(AppColors.ink)
                                                .lineLimit(1)
                                                .frame(width: 120, alignment: .leading)
                                                .padding(.horizontal, 4)
                                            Text(inv.customer?.displayName ?? "—")
                                                .font(.system(size: 13))
                                                .foregroundStyle(AppColors.ink)
                                                .lineLimit(1)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.horizontal, 4)
                                            Text(inv.invoiceDate, style: .date)
                                                .font(.system(size: 13))
                                                .foregroundStyle(AppColors.inkMuted)
                                                .frame(width: 100, alignment: .leading)
                                                .padding(.horizontal, 4)
                                            Text(formatTotal(inv))
                                                .font(.system(size: 13))
                                                .foregroundStyle(AppColors.ink)
                                                .monospacedDigit()
                                                .frame(width: 110, alignment: .trailing)
                                                .padding(.horizontal, 4)
                                            InvoiceStatusBadge(status: inv.effectiveStatus)
                                                .frame(width: 80, alignment: .leading)
                                                .padding(.horizontal, 4)
                                        }
                                        .padding(.horizontal, AppSpacing.l)
                                    }
                                    .contextMenu {
                                        Button("Open") { openWindow(id: "invoice", value: inv.id) }
                                    }
                                    Divider().overlay(AppColors.cardStroke)
                                }
                            }
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.m, style: .continuous))
                .padding(.horizontal, AppSpacing.l)
                .padding(.bottom, AppSpacing.l)
                
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        // Return → open selected invoice
        .background {
            Button("") { openSelectedInvoice() }
                .keyboardShortcut(.return, modifiers: [])
                .frame(width: 0, height: 0)
                .opacity(0)
        }
        .onAppear {
            if let id = selectedInvoiceID, !invoices.contains(where: { $0.id == id }) {
                selectedInvoiceID = nil
            }
            navigationGuard?.reportDirty(documentDirtyTracker?.hasUnsavedInvoice ?? false)
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
        invoice.lineItems.reduce(Decimal(0)) { $0 + $1.amount }.asCurrency
    }
}

// MARK: - Status badge (Paid = emerald, Outstanding = amber, Overdue = rose)

private struct InvoiceStatusBadge: View {
    let status: InvoiceStatus

    private var tone: AppStatusBadge.Tone {
        switch status {
        case .paid:  return .success
        case .void:  return .danger
        case .draft: return .neutral
        case .sent:  return .warning
        }
    }

    var body: some View {
        AppStatusBadge(title: status.rawValue, tone: tone)
    }
}
