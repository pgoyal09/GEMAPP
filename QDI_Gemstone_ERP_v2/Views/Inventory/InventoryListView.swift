import SwiftUI
import SwiftData

// MARK: - Mode

enum InventoryListMode {
    case current, sold
}

// MARK: - View

struct InventoryListView: View {
    @Binding var navigateTo: NavigationItem
    let mode: InventoryListMode

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Gemstone.createdAt, order: .reverse) private var allGemstones: [Gemstone]

    @State var viewModel = InventoryViewModel()
    @State private var showEditSheet = false
    @State private var editingStone: Gemstone?

    // MARK: - Computed

    private var baseStones: [Gemstone] {
        switch mode {
        case .current:
            return allGemstones.filter { $0.grouping != .lot && $0.status != .sold }
        case .sold:
            return allGemstones.filter { $0.status == .sold }
        }
    }

    private var filteredStones: [Gemstone] {
        viewModel.filtered(from: baseStones)
    }

    private var selectedStone: Gemstone? {
        guard let id = viewModel.selectedStoneID else { return nil }
        return filteredStones.first { $0.persistentModelID == id }
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 0) {
            // Main list area
            VStack(spacing: 0) {
                topBar
                activeFilterPillsRow
                if viewModel.showFiltersPanel {
                    InventoryFilterBar(viewModel: viewModel)
                        .padding(.horizontal, AppSpacing.l)
                        .padding(.bottom, AppSpacing.s)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                tableContent
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Detail panel
            if let stone = selectedStone {
                Divider()
                    .background(AppColors.cardStroke)
                GemstoneDetailPanel(gemstone: stone, onEdit: {
                    editingStone = stone
                    showEditSheet = true
                })
                .frame(width: 296)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.showFiltersPanel)
        .animation(.easeInOut(duration: 0.2), value: selectedStone?.persistentModelID)
        .sheet(isPresented: $showEditSheet) {
            if let stone = editingStone {
                StoneFormView(mode: .edit(stone))
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        VStack(spacing: AppSpacing.s) {
            HStack(spacing: AppSpacing.s) {
                GlassSearchField(text: $viewModel.searchText, placeholder: "Search by SKU, type, color...")
                    .frame(maxWidth: 320)

                statusFilterPills

                Spacer()

                filterToggleButton

                if mode == .current {
                    GradientButton(title: "Quick Intake", icon: "plus.circle.fill") {
                        navigateTo = .quickIntake
                    }

                    Button {
                        navigateTo = .reviewQueue
                    } label: {
                        Label("Review Queue", systemImage: "list.bullet.clipboard")
                    }
                    .buttonStyle(.outline)
                }
            }
        }
        .padding(.horizontal, AppSpacing.l)
        .padding(.vertical, AppSpacing.m)
    }

    private var statusFilterPills: some View {
        HStack(spacing: AppSpacing.xs) {
            if mode == .current {
                ForEach([InventoryStatusFilter.all, .available, .onMemo], id: \.rawValue) { filter in
                    FilterPill(
                        title: filter.rawValue,
                        isActive: viewModel.statusFilter == filter
                    ) {
                        viewModel.statusFilter = filter
                    }
                }
            }
        }
    }

    private var filterToggleButton: some View {
        Button {
            viewModel.showFiltersPanel.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 14))
                Text("Filters")
                    .font(AppTypography.caption)
                if viewModel.hasActiveFilters {
                    Circle()
                        .fill(AppColors.primary)
                        .frame(width: 6, height: 6)
                }
            }
            .foregroundStyle(viewModel.showFiltersPanel ? AppColors.primary : AppColors.inkMuted)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(viewModel.showFiltersPanel ? AppColors.primary.opacity(0.15) : Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(viewModel.showFiltersPanel ? AppColors.primary.opacity(0.20) : Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Active Filter Pills

    @ViewBuilder
    private var activeFilterPillsRow: some View {
        let pills = viewModel.activeFilterPills
        if !pills.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.xs) {
                    ForEach(pills, id: \.label) { pill in
                        HStack(spacing: 4) {
                            Text(pill.label)
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.primary)
                            Button {
                                viewModel.removePill(pill)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(AppColors.primary.opacity(0.6))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(AppColors.primary.opacity(0.12))
                        )
                    }

                    Button {
                        viewModel.clearAllFilters()
                    } label: {
                        Text("Clear all")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.danger)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, AppSpacing.l)
                .padding(.bottom, AppSpacing.s)
            }
        }
    }

    // MARK: - Table

    private var tableMinWidth: CGFloat {
        let base = TableColumn.sku + TableColumn.type + TableColumn.shape + TableColumn.carat
            + TableColumn.color + TableColumn.clarity + TableColumn.price + TableColumn.status
        return base + (mode == .sold ? TableColumn.customer : 0) + 60
    }

    private var tableContent: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(spacing: 0) {
                tableHeader
                Divider().background(AppColors.cardStroke)

                if filteredStones.isEmpty {
                    EmptyStateView(
                        icon: mode == .sold ? "tag.slash" : "tray",
                        title: mode == .sold ? "No sold stones" : "No stones found",
                        subtitle: viewModel.hasActiveFilters ? "Try adjusting your filters" : nil
                    )
                    .frame(minWidth: tableMinWidth)
                } else {
                    VStack(spacing: 2) {
                        ForEach(filteredStones, id: \.persistentModelID) { stone in
                            stoneRow(stone)
                        }
                    }
                    .padding(.vertical, AppSpacing.xs)
                }
            }
            .frame(minWidth: tableMinWidth, maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .glassTable()
        .padding(.horizontal, AppSpacing.l)
        .padding(.bottom, AppSpacing.l)
    }

    private var tableHeader: some View {
        HStack(spacing: 0) {
            TableHeader(title: "SKU", width: TableColumn.sku, alignment: .leading)
            TableHeader(title: "Type", width: TableColumn.type, alignment: .leading)
            TableHeader(title: "Shape", width: TableColumn.shape, alignment: .leading)
            TableHeader(title: "Carats", width: TableColumn.carat, alignment: .trailing)
            TableHeader(title: "Color", width: TableColumn.color, alignment: .leading)
            TableHeader(title: "Clarity", width: TableColumn.clarity, alignment: .leading)
            TableHeader(title: "Price", width: TableColumn.price, alignment: .trailing)
            if mode == .sold {
                TableHeader(title: "Sold To", width: TableColumn.customer, alignment: .leading)
            }
            TableHeader(title: "Status", width: TableColumn.status, alignment: .center)
            Spacer()
        }
        .padding(.horizontal, AppSpacing.m)
        .padding(.vertical, AppSpacing.s)
    }

    private func stoneRow(_ stone: Gemstone) -> some View {
        HoverRow(isSelected: viewModel.selectedStoneID == stone.persistentModelID, onTap: {
            if viewModel.selectedStoneID == stone.persistentModelID {
                viewModel.selectedStoneID = nil
            } else {
                viewModel.selectedStoneID = stone.persistentModelID
            }
        }) {
            Text(stone.sku)
                .font(AppTypography.mono)
                .foregroundStyle(AppColors.ink)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: TableColumn.sku, alignment: .leading)

            StoneTypeBadge(type: stone.stoneType.rawValue)
                .frame(width: TableColumn.type, alignment: .leading)

            Text(stone.shape)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.ink)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: TableColumn.shape, alignment: .leading)

            Text(String(format: "%.2f", stone.caratWeight))
                .font(AppTypography.mono)
                .foregroundStyle(AppColors.ink)
                .lineLimit(1)
                .frame(width: TableColumn.carat, alignment: .trailing)

            Text(stone.color)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.ink)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: TableColumn.color, alignment: .leading)

            Text(stone.clarity)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.ink)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: TableColumn.clarity, alignment: .leading)

            Text(formattedPrice(stone.sellPrice))
                .font(AppTypography.mono)
                .foregroundStyle(AppColors.ink)
                .lineLimit(1)
                .frame(width: TableColumn.price, alignment: .trailing)

            if mode == .sold {
                Text(stone.currentLocation)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.inkMuted)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: TableColumn.customer, alignment: .leading)
            }

            statusBadge(for: stone.status)
                .frame(width: TableColumn.status, alignment: .center)

            Spacer()
        }
    }

    // MARK: - Helpers

    private func statusBadge(for status: GemstoneStatus) -> StatusBadge {
        switch status {
        case .available: return StatusBadge(title: "Available", tone: .success)
        case .onMemo:    return StatusBadge(title: "On Memo", tone: .warning)
        case .sold:      return StatusBadge(title: "Sold", tone: .accent)
        }
    }

    private func formattedPrice(_ price: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: price as NSDecimalNumber) ?? "$0"
    }
}
