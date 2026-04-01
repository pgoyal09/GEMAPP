import SwiftUI
import SwiftData

struct MemoListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel = MemoListViewModel()
    @State private var toastMessage: String?
    @State private var toastIsError = false

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            memoTable
            summaryFooter
        }
        .accessibilityIdentifier("MemoListView")
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
            if let msg = toastMessage {
                ToastOverlay(message: msg, isError: toastIsError)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation(reduceMotion ? nil : .default) { toastMessage = nil }
                        }
                    }
            }
        }
    }

    private var filteredMemos: [Memo] {
        viewModel.filtered(from: viewModel.fetchedMemos)
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: AppSpacing.comfortable) {
            GlassSearchField(text: $viewModel.searchText, placeholder: "Search memos...")
                .frame(maxWidth: 300)
            statusPills
            Spacer()
            Button { createNewMemo() } label: {
                Label("New Memo", systemImage: "plus")
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
            FilterPill(title: "Open", isActive: viewModel.statusFilter == .onMemo) {
                viewModel.statusFilter = .onMemo
            }
            FilterPill(title: "Returned", isActive: viewModel.statusFilter == .returned) {
                viewModel.statusFilter = .returned
            }
            FilterPill(title: "Sold", isActive: viewModel.statusFilter == .sold) {
                viewModel.statusFilter = .sold
            }
        }
    }

    // MARK: - Table

    private var memoTable: some View {
        let filtered = filteredMemos
        return VStack(spacing: 0) {
            headerRow
            Divider().background(AppColors.cardStroke)
            if filtered.isEmpty {
                EmptyStateView(icon: "doc.text", title: "No memos found")
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
            } else {
                ScrollView(.vertical) {
                    LazyVStack(spacing: 2) {
                        ForEach(filtered, id: \.persistentModelID) { memo in
                            memoRow(memo)
                                .onAppear {
                                    if memo.id == filtered.last?.id && viewModel.hasMore {
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
            sortableHeader("Ref #", key: "reference", width: TableColumn.memo)
            sortableHeader("Customer", key: "customer", width: TableColumn.customer)
            sortableHeader("Date", key: "date", width: TableColumn.date)
            TableHeader(title: "Items", width: TableColumn.quantity, alignment: .trailing)
            sortableHeader("Total", key: "total", width: TableColumn.price, alignment: .trailing)
            sortableHeader("Status", key: "status", width: TableColumn.status)
            Spacer()
        }
        .padding(.horizontal, AppSpacing.section)
        .padding(.vertical, AppSpacing.comfortable)
    }

    private func sortableHeader(_ title: String, key: String, width: CGFloat, alignment: Alignment = .leading) -> TableHeader {
        TableHeader(
            title: title,
            width: width,
            alignment: alignment,
            isSorted: viewModel.sortKey == key,
            ascending: viewModel.sortAscending,
            onTap: { viewModel.toggleSort(key) }
        )
    }

    private func memoRow(_ memo: Memo) -> some View {
        let isSelected = viewModel.selectedMemoID == memo.persistentModelID
        return HoverRow(isSelected: isSelected, onTap: {
            viewModel.selectedMemoID = memo.persistentModelID
        }) {
            Text("#\(memo.referenceNumber)")
                .font(AppTypography.mono)
                .foregroundStyle(AppColors.ink)
                .lineLimit(1)
                .frame(width: TableColumn.memo, alignment: .leading)
            Text(memo.customer?.displayName ?? "—")
                .font(AppTypography.body)
                .foregroundStyle(AppColors.inkMuted)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: TableColumn.customer, alignment: .leading)
            Text(memo.dateAssigned?.formatted(date: .abbreviated, time: .omitted) ?? "—")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.inkSubtle)
                .lineLimit(1)
                .frame(width: TableColumn.date, alignment: .leading)
            Text("\(memo.lineItems.count)")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.inkMuted)
                .lineLimit(1)
                .frame(width: TableColumn.quantity, alignment: .trailing)
            Text(memo.totalAmount.asCurrency)
                .font(AppTypography.mono)
                .foregroundStyle(AppColors.ink)
                .lineLimit(1)
                .frame(width: TableColumn.price, alignment: .trailing)
            statusBadge(memo.status)
                .frame(width: TableColumn.status, alignment: .leading)
            Spacer()
        }
        .frame(height: 32)
        .simultaneousGesture(TapGesture(count: 2).onEnded {
            openWindow(id: "memo", value: memo.persistentModelID)
        })
    }

    private func statusBadge(_ status: MemoStatus) -> some View {
        let tone: StatusBadge.Tone = switch status {
        case .onMemo: .accent
        case .returned: .warning
        case .sold: .success
        }
        return StatusBadge(title: status.rawValue, tone: tone)
    }

    // MARK: - Footer

    private var summaryFooter: some View {
        let memos = filteredMemos
        let totalAmount = memos.reduce(Decimal.zero) { $0 + $1.totalAmount }
        let openCount = memos.filter { $0.status == .onMemo }.count
        return HStack(spacing: AppSpacing.hero) {
            Text("\(memos.count) memo\(memos.count == 1 ? "" : "s")")
                .font(AppTypography.caption.bold())
                .foregroundStyle(AppColors.ink)
            Text("Open: \(openCount)")
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

    private func createNewMemo() {
        do {
            let memo = try TransactionService.createMemo(modelContext: modelContext)
            openWindow(id: "memo", value: memo.persistentModelID)
        } catch {
            toastIsError = true
            withAnimation(reduceMotion ? nil : .default) { toastMessage = "Failed to create memo: \(ErrorMapper.userMessage(from: error))" }
        }
    }
}
