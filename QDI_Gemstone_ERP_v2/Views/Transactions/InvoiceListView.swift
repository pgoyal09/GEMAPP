import SwiftUI
import SwiftData
import AppKit

struct InvoiceListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @State private var viewModel = InvoiceListViewModel()
    @State private var isExportingBatch = false
    @State private var batchToastMessage: String?
    @State private var batchToastIsError = false
    @State private var batchCompleted = 0
    @State private var batchFailed = 0

    private var allInvoices: [Invoice] { viewModel.fetchedInvoices }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            invoiceTable
        }
        .onAppear { viewModel.fetchPage(context: modelContext) }
        .onChange(of: viewModel.statusFilter) { _, _ in
            viewModel.refetch(context: modelContext)
        }
        .overlay {
            if let msg = batchToastMessage {
                ToastOverlay(message: msg, isError: batchToastIsError)
                    .animation(.easeInOut, value: batchToastMessage)
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: AppSpacing.cozy) {
            GlassSearchField(text: $viewModel.searchText, placeholder: "Search invoices…")
                .frame(maxWidth: 300)
            statusPills
            Spacer()

            Button("Export All PDFs") { batchExportPDFs() }
                .buttonStyle(.outline)
                .disabled(isExportingBatch || allInvoices.isEmpty)
                .help("Export all visible invoices as individual PDF files")

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
            LazyVStack(spacing: 0) {
                headerRow
                Divider().background(AppColors.cardStroke)
                if filtered.isEmpty {
                    EmptyStateView(icon: "dollarsign.circle", title: "No invoices found")
                        .frame(minWidth: invoiceTableMinWidth)
                        .frame(height: 200)
                } else {
                    LazyVStack(spacing: 2) {
                        ForEach(filtered) { invoice in
                            invoiceRow(invoice)
                                .onAppear {
                                    if invoice.id == filtered.last?.id && viewModel.hasMore {
                                        viewModel.loadMore(context: modelContext)
                                    }
                                }
                        }
                    }
                    .padding(.vertical, AppSpacing.xs)

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

    private func batchExportPDFs() {
        let panel = NSOpenPanel()
        panel.title = "Choose Export Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let folder = panel.url else { return }

        let filtered = viewModel.filtered(from: allInvoices)
        guard !filtered.isEmpty else { return }
        isExportingBatch = true
        batchCompleted = 0
        batchFailed = 0
        let total = filtered.count

        Task { @MainActor in
            let maxConcurrency = 3
            var idx = 0

            // Process in batches of maxConcurrency
            while idx < filtered.count {
                let batchEnd = min(idx + maxConcurrency, filtered.count)
                let batch = Array(filtered[idx..<batchEnd])
                idx = batchEnd

                await withTaskGroup(of: Bool.self) { group in
                    for invoice in batch {
                        let refNum = invoice.referenceNumber
                        group.addTask { @MainActor in
                            await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                                PDFService.shared.generatePDF(invoice: invoice) { result in
                                    switch result {
                                    case .success(let tempURL):
                                        let destURL = folder.appendingPathComponent("Invoice-\(refNum).pdf")
                                        do {
                                            let fm = FileManager.default
                                            if fm.fileExists(atPath: destURL.path) {
                                                try fm.removeItem(at: destURL)
                                            }
                                            try fm.copyItem(at: tempURL, to: destURL)
                                        } catch {
                                            continuation.resume(returning: false)
                                            PDFService.shared.cleanupTempFile(at: tempURL)
                                            return
                                        }
                                        PDFService.shared.cleanupTempFile(at: tempURL)
                                        continuation.resume(returning: true)
                                    case .failure:
                                        continuation.resume(returning: false)
                                    }
                                }
                            }
                        }
                    }
                    for await success in group {
                        if !success { batchFailed += 1 }
                        batchCompleted += 1
                    }
                }
            }

            isExportingBatch = false
            let exported = total - batchFailed
            if batchFailed > 0 {
                batchToastIsError = true
                batchToastMessage = "Exported \(exported) of \(total) (\(batchFailed) failed)"
            } else {
                batchToastIsError = false
                batchToastMessage = "Exported \(total) invoice PDF\(total == 1 ? "" : "s")"
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation { batchToastMessage = nil }
            }
        }
    }

    private func createNewInvoice() {
        do {
            let inv = try TransactionService.createInvoice(modelContext: modelContext)
            openWindow(id: "invoice", value: inv.persistentModelID)
        } catch {
            batchToastIsError = true
            withAnimation { batchToastMessage = "Failed to create invoice: \(ErrorMapper.userMessage(from: error))" }
        }
    }
}
