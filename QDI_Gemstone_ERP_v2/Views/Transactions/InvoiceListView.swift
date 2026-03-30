import SwiftUI
import SwiftData

struct InvoiceListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @Query(sort: \Invoice.invoiceDate, order: .reverse) private var allInvoices: [Invoice]
    @State private var viewModel = InvoiceListViewModel()

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            invoiceTable
        }
    }

    private var toolbar: some View {
        HStack(spacing: AppSpacing.cozy) {
            GlassSearchField(text: $viewModel.searchText, placeholder: "Search invoices…")
                .frame(maxWidth: 300)
            statusPills
            Spacer()
            Button { createNewInvoice() } label: {
                Label("New Invoice", systemImage: "plus")
            }
            .buttonStyle(.gradient)
        }
        .padding(.horizontal, AppSpacing.l)
        .padding(.vertical, AppSpacing.m)
    }

    private var statusPills: some View {
        HStack(spacing: 6) {
            FilterPill(title: "All", isActive: viewModel.statusFilter == nil) {
                viewModel.statusFilter = nil
            }
            ForEach(InvoiceStatus.allCases, id: \.self) { status in
                FilterPill(title: status.rawValue, isActive: viewModel.statusFilter == status) {
                    viewModel.statusFilter = status
                }
            }
        }
    }

    private let invoiceTableMinWidth: CGFloat =
        TableColumn.invoice + TableColumn.customer + TableColumn.date
        + TableColumn.price + TableColumn.status + 60

    private var invoiceTable: some View {
        let filtered = viewModel.filtered(from: allInvoices)
        return ScrollView([.horizontal, .vertical]) {
            VStack(spacing: 0) {
                headerRow
                Divider().background(AppColors.cardStroke)
                if filtered.isEmpty {
                    EmptyStateView(icon: "dollarsign.circle", title: "No invoices found")
                        .frame(minWidth: invoiceTableMinWidth)
                        .frame(height: 200)
                } else {
                    VStack(spacing: 2) {
                        ForEach(filtered) { invoice in
                            invoiceRow(invoice)
                        }
                    }
                    .padding(.vertical, AppSpacing.xs)

                    // Summary footer
                    invoiceSummaryFooter(filtered)
                }
            }
            .frame(minWidth: invoiceTableMinWidth, maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .glassTable()
        .padding(.horizontal, AppSpacing.l)
        .padding(.bottom, AppSpacing.l)
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            invoiceSortableHeader("Invoice #", key: "reference", width: TableColumn.invoice)
            invoiceSortableHeader("Customer", key: "customer", width: TableColumn.customer)
            invoiceSortableHeader("Date", key: "date", width: TableColumn.date)
            invoiceSortableHeader("Total", key: "total", width: TableColumn.price)
            invoiceSortableHeader("Status", key: "status", width: TableColumn.status)
            Spacer()
        }
        .padding(.horizontal, AppSpacing.m)
        .padding(.vertical, AppSpacing.s)
    }

    private func invoiceSortableHeader(_ title: String, key: String, width: CGFloat) -> TableHeader {
        TableHeader(
            title: title,
            width: width,
            isSorted: viewModel.sortKey == key,
            ascending: viewModel.sortAscending,
            onTap: { viewModel.toggleSort(key) }
        )
    }

    private func invoiceRow(_ invoice: Invoice) -> some View {
        let isSelected = viewModel.selectedInvoiceID == invoice.persistentModelID
        return HoverRow(isSelected: isSelected, onTap: {
            viewModel.selectedInvoiceID = invoice.persistentModelID
        }) {
            Text(invoice.referenceNumber.isEmpty ? "—" : invoice.referenceNumber)
                .font(AppTypography.mono)
                .foregroundStyle(AppColors.ink)
                .lineLimit(1)
                .frame(width: TableColumn.invoice, alignment: .leading)
            Text(invoice.customer?.displayName ?? "—")
                .font(AppTypography.body)
                .foregroundStyle(AppColors.inkMuted)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: TableColumn.customer, alignment: .leading)
            Text(invoice.invoiceDate.formatted(date: .abbreviated, time: .omitted))
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.inkSubtle)
                .lineLimit(1)
                .frame(width: TableColumn.date, alignment: .leading)
            Text(invoice.totalAmount.asCurrency)
                .font(AppTypography.mono)
                .foregroundStyle(AppColors.ink)
                .lineLimit(1)
                .frame(width: TableColumn.price, alignment: .trailing)
            invoiceStatusBadge(invoice.status)
                .frame(width: TableColumn.status, alignment: .leading)
            Spacer()
        }
        .simultaneousGesture(TapGesture(count: 2).onEnded {
            openWindow(id: "invoice", value: invoice.persistentModelID)
        })
    }

    private func invoiceSummaryFooter(_ invoices: [Invoice]) -> some View {
        let totalAmount = invoices.reduce(Decimal.zero) { $0 + $1.totalAmount }
        let paidCount = invoices.filter { $0.status == .paid }.count
        return HStack(spacing: AppSpacing.l) {
            Text("\(invoices.count) invoice\(invoices.count == 1 ? "" : "s")")
                .font(AppTypography.caption.bold())
                .foregroundStyle(AppColors.ink)
            Text("Paid: \(paidCount)")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.inkMuted)
            Text("Total: \(totalAmount.asCurrency)")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.inkMuted)
            Spacer()
        }
        .padding(.horizontal, AppSpacing.m)
        .padding(.vertical, AppSpacing.s)
        .background(Color.white.opacity(0.03))
    }

    private func invoiceStatusBadge(_ status: InvoiceStatus) -> some View {
        let tone: StatusBadge.Tone = switch status {
        case .draft: .neutral
        case .sent: .accent
        case .paid: .success
        case .void: .danger
        }
        return StatusBadge(title: status.rawValue, tone: tone)
    }

    private func createNewInvoice() {
        do {
            let inv = try TransactionService.createInvoice(modelContext: modelContext)
            openWindow(id: "invoice", value: inv.persistentModelID)
        } catch {
            print("[InvoiceListView] Failed to create invoice: \(error.localizedDescription)")
        }
    }
}
