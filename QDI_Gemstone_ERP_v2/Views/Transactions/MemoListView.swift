import SwiftUI
import SwiftData

struct MemoListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @State private var viewModel = MemoListViewModel()
    @State private var toastMessage: String?
    @State private var toastIsError = false

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            memoTable
        }
        .onAppear { viewModel.fetchPage(context: modelContext) }
        .onChange(of: viewModel.statusFilter) { _, _ in
            viewModel.refetch(context: modelContext)
        }
        .overlay {
            if let msg = toastMessage {
                ToastOverlay(message: msg, isError: toastIsError)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation { toastMessage = nil }
                        }
                    }
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: AppSpacing.cozy) {
            GlassSearchField(text: $viewModel.searchText, placeholder: "Search memos…")
                .frame(maxWidth: 300)
            statusPills
            Spacer()
            Button { createNewMemo() } label: {
                Label("New Memo", systemImage: "plus")
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

    private let memoTableMinWidth: CGFloat =
        TableColumn.memo + TableColumn.customer + TableColumn.date
        + TableColumn.quantity + TableColumn.price + TableColumn.status + 60

    private var memoTable: some View {
        let filtered = viewModel.filtered(from: viewModel.fetchedMemos)
        return ScrollView([.horizontal, .vertical]) {
            LazyVStack(spacing: 0) {
                headerRow
                Divider().background(AppColors.cardStroke)
                if filtered.isEmpty {
                    EmptyStateView(icon: "doc.text", title: "No memos found")
                        .frame(minWidth: memoTableMinWidth)
                        .frame(height: 200)
                } else {
                    LazyVStack(spacing: 2) {
                        ForEach(filtered) { memo in
                            memoRow(memo)
                                .onAppear {
                                    if memo.id == filtered.last?.id && viewModel.hasMore {
                                        viewModel.loadMore(context: modelContext)
                                    }
                                }
                        }
                    }
                    .padding(.vertical, AppSpacing.xs)

                    memoSummaryFooter(filtered)
                }
            }
            .frame(minWidth: memoTableMinWidth, maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .glassTable()
        .padding(.horizontal, AppSpacing.l)
        .padding(.bottom, AppSpacing.l)
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            memoSortableHeader("Memo #", key: "reference", width: TableColumn.memo)
            memoSortableHeader("Customer", key: "customer", width: TableColumn.customer)
            memoSortableHeader("Date", key: "date", width: TableColumn.date)
            TableHeader(title: "Age", width: TableColumn.quantity)
            memoSortableHeader("Amount", key: "total", width: TableColumn.price)
            memoSortableHeader("Status", key: "status", width: TableColumn.status)
            Spacer()
        }
        .padding(.horizontal, AppSpacing.m)
        .padding(.vertical, AppSpacing.s)
    }

    private func memoSortableHeader(_ title: String, key: String, width: CGFloat) -> TableHeader {
        TableHeader(
            title: title,
            width: width,
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
            Text("\(memo.ageInDays)d")
                .font(AppTypography.caption)
                .foregroundStyle(memoAgingColor(days: memo.ageInDays))
                .lineLimit(1)
                .frame(width: TableColumn.quantity, alignment: .leading)
            Text(memo.totalAmount.asCurrency)
                .font(AppTypography.mono)
                .foregroundStyle(AppColors.ink)
                .lineLimit(1)
                .frame(width: TableColumn.price, alignment: .trailing)
            memoStatusBadge(memo.status)
                .frame(width: TableColumn.status, alignment: .leading)
            Spacer()
        }
        .simultaneousGesture(TapGesture(count: 2).onEnded {
            openWindow(id: "memo", value: memo.persistentModelID)
        })
    }

    private func memoStatusBadge(_ status: MemoStatus) -> some View {
        let tone: StatusBadge.Tone = switch status {
        case .onMemo: .accent
        case .returned: .warning
        case .sold: .success
        }
        return StatusBadge(title: status.rawValue, tone: tone)
    }

    private func memoSummaryFooter(_ memos: [Memo]) -> some View {
        let totalAmount = memos.reduce(Decimal.zero) { $0 + $1.totalAmount }
        let openCount = memos.filter { $0.status == .onMemo }.count
        return HStack(spacing: AppSpacing.l) {
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
        .padding(.horizontal, AppSpacing.m)
        .padding(.vertical, AppSpacing.s)
        .background(Color.white.opacity(0.03))
    }

    private func memoAgingColor(days: Int) -> Color {
        switch days {
        case ..<30: return AppColors.success
        case 30..<60: return AppColors.warning
        case 60..<90: return Color.orange
        default: return AppColors.danger
        }
    }

    private func createNewMemo() {
        do {
            let memo = try TransactionService.createMemo(modelContext: modelContext)
            openWindow(id: "memo", value: memo.persistentModelID)
        } catch {
            toastIsError = true
            withAnimation { toastMessage = "Failed to create memo: \(ErrorMapper.userMessage(from: error))" }
        }
    }
}
