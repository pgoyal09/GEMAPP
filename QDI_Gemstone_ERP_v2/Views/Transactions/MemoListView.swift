import SwiftUI
import SwiftData

struct MemoListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @Query(sort: \Memo.createdAt, order: .reverse) private var allMemos: [Memo]
    @State private var viewModel = MemoListViewModel()

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            memoTable
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            GlassSearchField(text: $viewModel.searchText, placeholder: "Search memos…")
                .frame(maxWidth: 300)
            statusPills
            Spacer()
            Button { createNewMemo() } label: {
                Label("New Memo", systemImage: "plus")
            }
            .buttonStyle(.gradient)
            .keyboardShortcut("n", modifiers: .command)
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
        let filtered = viewModel.filtered(from: allMemos)
        return ScrollView([.horizontal, .vertical]) {
            VStack(spacing: 0) {
                headerRow
                Divider().background(AppColors.cardStroke)
                if filtered.isEmpty {
                    EmptyStateView(icon: "doc.text", title: "No memos found")
                        .frame(minWidth: memoTableMinWidth)
                        .frame(height: 200)
                } else {
                    VStack(spacing: 2) {
                        ForEach(filtered) { memo in
                            memoRow(memo)
                        }
                    }
                    .padding(.vertical, AppSpacing.xs)
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
            TableHeader(title: "Memo #", width: TableColumn.memo)
            TableHeader(title: "Customer", width: TableColumn.customer)
            TableHeader(title: "Date", width: TableColumn.date)
            TableHeader(title: "Age", width: TableColumn.quantity)
            TableHeader(title: "Amount", width: TableColumn.price)
            TableHeader(title: "Status", width: TableColumn.status)
            Spacer()
        }
        .padding(.horizontal, AppSpacing.m)
        .padding(.vertical, AppSpacing.s)
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
                .foregroundStyle(AppColors.inkSubtle)
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

    private func createNewMemo() {
        do {
            let memo = try TransactionService.createMemo(modelContext: modelContext)
            openWindow(id: "memo", value: memo.persistentModelID)
        } catch {
            print("[MemoListView] Failed to create memo: \(error.localizedDescription)")
        }
    }
}
