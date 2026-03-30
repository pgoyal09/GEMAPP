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

    @State var viewModel = InventoryViewModel()
    @State private var showEditSheet = false
    @State private var editingStone: Gemstone?
    @State private var selectedStones: Set<PersistentIdentifier> = []
    @State private var toastMessage: String?
    @State private var toastIsError = false

    @Environment(\.openWindow) private var openWindow

    // MARK: - Computed

    private var filteredStones: [Gemstone] {
        viewModel.filtered(from: viewModel.fetchedStones)
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
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .accessibilityIdentifier("InventoryListView")
        .onAppear { viewModel.fetchPage(context: modelContext, mode: mode) }
        .animation(AppAnimation.standard, value: viewModel.showFiltersPanel)
        .animation(AppAnimation.sheetSpring, value: selectedStone?.persistentModelID)
        .overlay(alignment: .bottom) {
            if !selectedStones.isEmpty {
                multiSelectActionBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(AppAnimation.standard, value: selectedStones.isEmpty)
            }
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
        .onChange(of: viewModel.searchText) { _, _ in selectedStones.removeAll() }
        .onChange(of: viewModel.statusFilter) { _, _ in
            selectedStones.removeAll()
            viewModel.refetch(context: modelContext)
        }
        .onChange(of: viewModel.stoneTypeFilter) { _, _ in
            selectedStones.removeAll()
            viewModel.refetch(context: modelContext)
        }
        .onChange(of: viewModel.shapeFilter) { _, _ in selectedStones.removeAll() }
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
        .accessibilityLabel("Toggle Filters")
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
                            .accessibilityLabel("Remove \(pill.label) filter")
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
            + TableColumn.color + TableColumn.clarity + TableColumn.price + TableColumn.status + 90
        return base + (mode == .sold ? TableColumn.customer : 0) + 60
    }

    private var tableContent: some View {
        ScrollView([.horizontal, .vertical]) {
            LazyVStack(spacing: 0) {
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
                    LazyVStack(spacing: 2) {
                        ForEach(filteredStones, id: \.persistentModelID) { stone in
                            stoneRow(stone)
                                .onAppear {
                                    if stone.persistentModelID == filteredStones.last?.persistentModelID && viewModel.hasMore {
                                        viewModel.loadMore(context: modelContext)
                                    }
                                }
                        }
                    }
                    .padding(.vertical, AppSpacing.xs)

                    summaryFooter
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
            sortableHeader("SKU", key: "sku", width: TableColumn.sku, alignment: .leading)
            sortableHeader("Type", key: "type", width: TableColumn.type, alignment: .leading)
            sortableHeader("Shape", key: "shape", width: TableColumn.shape, alignment: .leading)
            sortableHeader("Carats", key: "carats", width: TableColumn.carat, alignment: .trailing)
            TableHeader(title: "Color", width: TableColumn.color, alignment: .leading)
            TableHeader(title: "Clarity", width: TableColumn.clarity, alignment: .leading)
            sortableHeader("Price", key: "price", width: TableColumn.price, alignment: .trailing)
            if mode == .sold {
                TableHeader(title: "Sold To", width: TableColumn.customer, alignment: .leading)
            }
            sortableHeader("Status", key: "status", width: TableColumn.status, alignment: .center)
            sortableHeader("Date Added", key: "dateAdded", width: 90, alignment: .leading)
            Spacer()
        }
        .padding(.horizontal, AppSpacing.m)
        .padding(.vertical, AppSpacing.s)
    }

    private func sortableHeader(_ title: String, key: String, width: CGFloat, alignment: Alignment) -> TableHeader {
        TableHeader(
            title: title,
            width: width,
            alignment: alignment,
            isSorted: viewModel.sortKey == key,
            ascending: viewModel.sortAscending,
            onTap: { viewModel.toggleSort(key) }
        )
    }

    private func stoneRow(_ stone: Gemstone) -> some View {
        HoverRow(isSelected: viewModel.selectedStoneID == stone.persistentModelID, onTap: {
            if viewModel.selectedStoneID == stone.persistentModelID {
                viewModel.selectedStoneID = nil
            } else {
                viewModel.selectedStoneID = stone.persistentModelID
            }
        }) {
            if mode == .current {
                Toggle(isOn: Binding(
                    get: { selectedStones.contains(stone.persistentModelID) },
                    set: { isOn in
                        if isOn { selectedStones.insert(stone.persistentModelID) }
                        else { selectedStones.remove(stone.persistentModelID) }
                    }
                )) { EmptyView() }
                .toggleStyle(.checkbox)
                .frame(width: 24)
                .accessibilityLabel("Select \(stone.sku)")
            }

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

            Text(stone.createdAt.formatted(.dateTime.month(.abbreviated).day()))
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.inkMuted)
                .lineLimit(1)
                .frame(width: 90, alignment: .leading)

            Spacer()
        }
    }

    // MARK: - Summary Footer

    private var summaryFooter: some View {
        let stones = filteredStones
        let totalCarats = stones.reduce(0.0) { $0 + $1.caratWeight }
        let totalValue = stones.reduce(Decimal.zero) { $0 + $1.sellPrice * Decimal($1.caratWeight) }
        return HStack(spacing: AppSpacing.l) {
            Text("\(stones.count) stone\(stones.count == 1 ? "" : "s")")
                .font(AppTypography.caption.bold())
                .foregroundStyle(AppColors.ink)
            Text("Total: \(String(format: "%.2f", totalCarats)) ct")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.inkMuted)
            Text("Value: \(totalValue.asCurrency)")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.inkMuted)
            if viewModel.fetchedStones.count != stones.count {
                Text("(of \(viewModel.fetchedStones.count) loaded)")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.inkSubtle)
            }
            Spacer()
        }
        .padding(.horizontal, AppSpacing.m)
        .padding(.vertical, AppSpacing.s)
        .background(Color.white.opacity(0.03))
    }

    // MARK: - Helpers

    private func statusBadge(for status: GemstoneStatus) -> StatusBadge {
        switch status {
        case .available:    return StatusBadge(title: "Available", tone: .success)
        case .onMemo:       return StatusBadge(title: "On Memo", tone: .warning)
        case .sold:         return StatusBadge(title: "Sold", tone: .accent)
        case .atLab:        return StatusBadge(title: "At Lab", tone: .accent)
        case .reserved:     return StatusBadge(title: "Reserved", tone: .warning)
        case .inTransit:    return StatusBadge(title: "In Transit", tone: .accent)
        case .consignment:  return StatusBadge(title: "Consignment", tone: .neutral)
        }
    }

    private func formattedPrice(_ price: Decimal) -> String {
        price.asCurrency
    }

    // MARK: - Multi-Select Action Bar

    private var multiSelectActionBar: some View {
        HStack(spacing: AppSpacing.m) {
            Text("\(selectedStones.count) stone\(selectedStones.count == 1 ? "" : "s") selected")
                .font(AppTypography.body)
                .foregroundStyle(AppColors.ink)

            Spacer()

            GradientButton(title: "Create Memo with \(selectedStones.count) stones", icon: "doc.text") {
                createMemoWithSelectedStones()
            }

            GradientButton(title: "Create Invoice with \(selectedStones.count) stones", icon: "doc.text.fill") {
                createInvoiceWithSelectedStones()
            }

            Button("Clear Selection") {
                selectedStones.removeAll()
            }
            .buttonStyle(.outline)
        }
        .padding(.horizontal, AppSpacing.l)
        .padding(.vertical, AppSpacing.m)
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.m, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCornerRadius.m, style: .continuous)
                        .strokeBorder(AppColors.primary.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.3), radius: 12, y: -4)
        )
        .padding(.horizontal, AppSpacing.l)
        .padding(.bottom, AppSpacing.m)
    }

    private func createMemoWithSelectedStones() {
        let stones = filteredStones.filter { selectedStones.contains($0.persistentModelID) }
        guard !stones.isEmpty else { return }
        do {
            let memo = try TransactionService.createMemo(modelContext: modelContext)
            for stone in stones {
                try TransactionService.addStone(stone, to: memo, modelContext: modelContext)
            }
            selectedStones.removeAll()
            openWindow(id: "memo", value: memo.persistentModelID)
        } catch {
            toastIsError = true
            withAnimation { toastMessage = "Failed to create memo: \(ErrorMapper.userMessage(from: error))" }
        }
    }

    private func createInvoiceWithSelectedStones() {
        let stones = filteredStones.filter { selectedStones.contains($0.persistentModelID) }
        guard !stones.isEmpty else { return }
        do {
            let invoice = try TransactionService.createInvoice(modelContext: modelContext)
            for stone in stones {
                try TransactionService.addStone(stone, to: invoice, modelContext: modelContext)
            }
            selectedStones.removeAll()
            openWindow(id: "invoice", value: invoice.persistentModelID)
        } catch {
            toastIsError = true
            withAnimation { toastMessage = "Failed to create invoice: \(ErrorMapper.userMessage(from: error))" }
        }
    }
}
