import SwiftUI
import SwiftData
import AppKit

struct InvoiceListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel = InvoiceListViewModel()
    @State private var isExportingBatch = false
    @State private var batchToastMessage: String?
    @State private var batchToastIsError = false
    @State private var batchCompleted = 0
    @State private var batchFailed = 0

    private var allInvoices: [Invoice] { viewModel.fetchedInvoices }

    private var filteredInvoices: [Invoice] {
        viewModel.filtered(from: allInvoices)
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            invoiceTable
            summaryFooter
        }
        .accessibilityIdentifier("InvoiceListView")
        .onAppear { viewModel.fetchPage(context: modelContext) }
        .onChange(of: viewModel.statusFilter) { _, _ in
            viewModel.refetch(context: modelContext)
        }
        .onReceive(NotificationCenter.default.publisher(for: .memoOrInvoiceDidSave)) { _ in
            viewModel.refetch(context: modelContext)
        }
        .onReceive(NotificationCenter.default.publisher(for: .dataStoreDidChange)) { _ in
            viewModel.refetch(context: modelContext)
        }
        .overlay {
            if let msg = batchToastMessage {
                ToastOverlay(message: msg, isError: batchToastIsError)
                    .animation(reduceMotion ? nil : AppAnimation.standard, value: batchToastMessage)
            }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: AppSpacing.comfortable) {
            GlassSearchField(text: $viewModel.searchText, placeholder: "Search invoices...")
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
        .padding(.horizontal, AppSpacing.hero)
        .padding(.vertical, AppSpacing.section)
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

    // MARK: - Table

    private var invoiceTable: some View {
        let filtered = filteredInvoices
        return VStack(spacing: 0) {
            headerRow
            Divider().background(AppColors.cardStroke)
            if filtered.isEmpty {
                EmptyStateView(icon: "dollarsign.circle", title: "No invoices found")
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
            } else {
                ScrollView(.vertical) {
                    LazyVStack(spacing: 2) {
                        ForEach(filtered, id: \.persistentModelID) { invoice in
                            invoiceRow(invoice)
                                .onAppear {
                                    if invoice.id == filtered.last?.id && viewModel.hasMore {
                                        viewModel.loadMore(context: modelContext)
                                    }
                                }
                        }
                    }
                    .padding(.vertical, AppSpacing.standard)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: AppCornerRadius.card)
                .stroke(AppColors.cardStroke, lineWidth: 1)
        )
        .padding(.horizontal, AppSpacing.hero)
        .padding(.bottom, AppSpacing.comfortable)
    }

    private var headerRow: some View {
        HStack(spacing: 4) {
            sortableHeader("Ref #", key: "reference", width: TableColumn.invoice, flex: true)
            sortableHeader("Customer", key: "customer", width: TableColumn.customer, flex: true)
            sortableHeader("Date", key: "date", width: TableColumn.date, flex: true)
            TableHeader(title: "Items", width: TableColumn.quantity, flex: true, alignment: .trailing)
            sortableHeader("Total", key: "total", width: TableColumn.price, flex: true, alignment: .trailing)
            sortableHeader("Status", key: "status", width: 110, flex: true)
        }
        .padding(.horizontal, AppSpacing.standard)
        .padding(.vertical, AppSpacing.comfortable)
    }

    private func sortableHeader(_ title: String, key: String, width: CGFloat, flex: Bool = false, alignment: Alignment = .leading, minWidth: CGFloat? = nil) -> TableHeader {
        TableHeader(
            title: title,
            width: minWidth ?? width,
            flex: flex || minWidth != nil,
            alignment: alignment,
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
                .frame(minWidth: TableColumn.invoice, maxWidth: .infinity, alignment: .leading)
            Text(invoice.customer?.displayName ?? "—")
                .font(AppTypography.body)
                .foregroundStyle(AppColors.inkMuted)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(minWidth: TableColumn.customer, maxWidth: .infinity, alignment: .leading)
            Text(invoice.invoiceDate.formatted(date: .abbreviated, time: .omitted))
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.inkSubtle)
                .lineLimit(1)
                .frame(minWidth: TableColumn.date, maxWidth: .infinity, alignment: .leading)
            Text("\(invoice.lineItems.count)")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.inkMuted)
                .lineLimit(1)
                .frame(minWidth: TableColumn.quantity, maxWidth: .infinity, alignment: .trailing)
            Text(invoice.totalAmount.asCurrency)
                .font(AppTypography.mono)
                .foregroundStyle(AppColors.ink)
                .lineLimit(1)
                .frame(minWidth: TableColumn.price, maxWidth: .infinity, alignment: .trailing)
            statusBadge(invoice.status)
                .frame(minWidth: 110, maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 32)
        .simultaneousGesture(TapGesture(count: 2).onEnded {
            openWindow(id: "invoice", value: invoice.persistentModelID)
        })
    }

    private func statusBadge(_ status: InvoiceStatus) -> some View {
        let tone: StatusBadge.Tone = switch status {
        case .draft: .neutral
        case .sent: .accent
        case .paid: .success
        case .void: .danger
        }
        return StatusBadge(title: status.rawValue, tone: tone)
    }

    // MARK: - Footer

    private var summaryFooter: some View {
        let invoices = filteredInvoices
        let totalAmount = invoices.reduce(Decimal.zero) { $0 + $1.totalAmount }
        let paidCount = invoices.filter { $0.status == .paid }.count
        return HStack(spacing: AppSpacing.hero) {
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
        .padding(.horizontal, AppSpacing.hero)
        .padding(.vertical, AppSpacing.comfortable)
        .background(AppColors.cardBackground)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppColors.cardStroke)
                .frame(height: 1)
        }
    }

    // MARK: - Actions

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
            for invoice in filtered {
                let refNum = invoice.referenceNumber
                let success: Bool = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                    PDFService.shared.generatePDF(invoice: invoice) { result in
                        DispatchQueue.main.async {
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
                if !success { batchFailed += 1 }
                batchCompleted += 1
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
                withAnimation(reduceMotion ? nil : .default) { batchToastMessage = nil }
            }
        }
    }

    private func createNewInvoice() {
        do {
            let inv = try TransactionService.createInvoice(modelContext: modelContext)
            openWindow(id: "invoice", value: inv.persistentModelID)
        } catch {
            batchToastIsError = true
            withAnimation(reduceMotion ? nil : .default) { batchToastMessage = "Failed to create invoice: \(ErrorMapper.userMessage(from: error))" }
        }
    }
}
