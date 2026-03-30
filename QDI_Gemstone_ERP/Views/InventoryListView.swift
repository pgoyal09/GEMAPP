import SwiftUI
import SwiftData

enum InventoryListMode {
    case current   /// Non-sold only (available + on memo)
    case sold      /// Sold items only
}

struct InventoryListView: View {
    @Binding var selectedNavigationItem: NavigationItem
    var mode: InventoryListMode = .current
    @Environment(\.modelContext) var modelContext
    @Environment(\.openWindow) var openWindow
    @Query(sort: \Gemstone.sku) private var allGemstones: [Gemstone]
    @State var viewModel = InventoryViewModel()
    @State var selectedStoneID: PersistentIdentifier?
    @State var showEditSheet = false
    @State private var showColorColumn = false
    #if DEBUG
    @State private var skuMismatchAlert: String?
    #endif

    private var baseGemstones: [Gemstone] {
        switch mode {
        case .current:
            return allGemstones.filter { $0.effectiveStatus != .sold && !$0.isLot }
        case .sold:
            return allGemstones.filter { $0.effectiveStatus == .sold && !$0.isLot }
        }
    }

    var filteredGemstones: [Gemstone] {
        viewModel.filtered(from: baseGemstones)
    }

    private var selectedStone: Gemstone? {
        guard let id = selectedStoneID else { return nil }
        return baseGemstones.first { $0.id == id }
    }

    private var availableCount: Int { baseGemstones.filter { $0.effectiveStatus == .available }.count }
    private var onMemoCount: Int { baseGemstones.filter { $0.effectiveStatus == .onMemo }.count }
    private var soldCount: Int { baseGemstones.filter { $0.effectiveStatus == .sold }.count }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                headerRow
                searchRow
                statusAndStoneTypeRow
                filterToggleRow
                if viewModel.hasActiveFilters {
                    filterPillsRow
                }
                if viewModel.showFiltersPanel {
                    inlineFilterPanel
                }
                summaryStrip
                tableContent
            }
            .frame(minWidth: 320, maxWidth: .infinity)
            .layoutPriority(1)

            Divider()

            Group {
                if let stone = selectedStone {
                    ScrollView(.vertical, showsIndicators: true) {
                        GemstoneDetailView(stone: stone)
                            .frame(minWidth: InspectorWidth.ideal, maxWidth: InspectorWidth.ideal, alignment: .leading)
                    }
                    .frame(minWidth: InspectorWidth.ideal, maxWidth: InspectorWidth.ideal)
                } else {
                    ContentUnavailableView(
                        "Select an Item",
                        systemImage: "diamond",
                        description: Text("Select a gemstone to view details.")
                    )
                }
            }
            .frame(minWidth: InspectorWidth.ideal, maxWidth: InspectorWidth.ideal, maxHeight: .infinity)
            .fixedSize(horizontal: true, vertical: false)
            .background(Color.white.opacity(0.02))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background)
        .sheet(isPresented: $showEditSheet) {
            if let stone = selectedStone {
                NavigationStack {
                    StoneFormView(
                        mode: .edit,
                        gemstone: stone,
                        onSave: { showEditSheet = false },
                        onDismiss: { showEditSheet = false }
                    )
                    .frame(minWidth: 980, minHeight: 480)
                    .navigationTitle("Edit: \(stone.sku)")
                }
                .id(stone.id)
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "Search inventory")
        // MARK: - Keyboard shortcuts
        .background {
            Group {
                // Space / Return → open edit sheet for selected stone
                Button("") { if selectedStone != nil { showEditSheet = true } }
                    .keyboardShortcut(.space, modifiers: [])
                Button("") { if selectedStone != nil { showEditSheet = true } }
                    .keyboardShortcut(.return, modifiers: [])
                // Cmd+E → edit selected
                Button("") { if selectedStone != nil { showEditSheet = true } }
                    .keyboardShortcut("e", modifiers: .command)
                // Cmd+N → go to Quick Intake
                Button("") { selectedNavigationItem = .quickIntake }
                    .keyboardShortcut("n", modifiers: .command)
            }
            .frame(width: 0, height: 0)
            .opacity(0)
        }
        #if DEBUG
        .alert("SKU Check", isPresented: Binding(get: { skuMismatchAlert != nil }, set: { if !$0 { skuMismatchAlert = nil } })) {
            Button("OK", role: .cancel) { skuMismatchAlert = nil }
        } message: {
            Text(skuMismatchAlert ?? "")
        }
        #endif
    }

    private var headerRow: some View {
        HStack {
            Text(mode == .sold ? "Sold Singles & Pairs" : "Single & Pair Inventory")
                .font(AppTypography.title)
                .foregroundStyle(AppColors.ink)
                #if DEBUG
                .contextMenu {
                    Button("Check SKU/type mismatches") {
                        let mismatches = SKUGenerator.findSKUTypeMismatches(modelContext: modelContext)
                        for s in mismatches {
                            print("[SKU] Mismatch: \(s.sku) has type \(s.stoneType.rawValue)")
                        }
                        skuMismatchAlert = mismatches.isEmpty ? "No mismatches found." : "\(mismatches.count) stone(s) with SKU/type mismatch. See console."
                    }
                }
                #endif
            Spacer()
            if mode == .current {
                GradientButton(title: "Quick Intake", icon: "plus.circle") { selectedNavigationItem = .quickIntake }
                GradientButton(title: "Review Queue", icon: "tray") { selectedNavigationItem = .reviewQueue }
            }
        }
        .padding()
    }

    private var searchRow: some View {
        GlassSearchField(text: $viewModel.searchText, placeholder: "Search by SKU, type, color, clarity, cert no, origin")
            .padding(.horizontal)
            .padding(.bottom, AppSpacing.s)
    }

    private var statusAndStoneTypeRow: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            if mode == .current {
                Picker("Status", selection: $viewModel.statusFilter) {
                    ForEach([InventoryStatusFilter.all, .available, .onMemo], id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            } else {
                Text("Sold items")
                    .font(.caption)
                    .foregroundStyle(AppColors.inkSubtle)
            }

            HStack(spacing: AppSpacing.xs) {
                ForEach(InventoryStoneTypeFilter.allCases, id: \.self) { type in
                    FilterPill(title: type.rawValue, isActive: viewModel.stoneTypeFilter == type) {
                        viewModel.stoneTypeFilter = type
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, AppSpacing.s)
    }

    private var filterToggleRow: some View {
        HStack(spacing: AppSpacing.m) {
            Button(viewModel.showFiltersPanel ? "Hide Filters" : "Show Filters") {
                viewModel.showFiltersPanel.toggle()
            }
            .buttonStyle(.borderless)

            if viewModel.hasActiveFilters {
                Button("Clear All") {
                    viewModel.clearAllFilters()
                }
                .buttonStyle(.borderless)
                .foregroundStyle(AppColors.inkMuted)
            }

            Spacer()
            Button(showColorColumn ? "Compact" : "Show Color") {
                showColorColumn.toggle()
            }
            .buttonStyle(.borderless)
            .foregroundStyle(AppColors.inkMuted)
            Text("\(filteredGemstones.count) shown")
                .font(.caption)
                .foregroundStyle(AppColors.inkSubtle)
        }
        .padding(.horizontal)
        .padding(.bottom, AppSpacing.s)
    }

    private var filterPillsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.xs) {
                ForEach(Array(viewModel.activeFilterPills.enumerated()), id: \.offset) { _, pill in
                    HStack(spacing: 4) {
                        Text(pill.label)
                            .font(.caption)
                            .foregroundStyle(AppColors.inkMuted)
                        Button {
                            viewModel.removePill(pill)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(AppColors.inkSubtle)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, AppSpacing.s)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                    )
                    .cornerRadius(8)
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, AppSpacing.s)
    }

    private var summaryStrip: some View {
        HStack(spacing: AppSpacing.l) {
            summaryItem("Total", value: "\(baseGemstones.count)")
            if mode == .current {
                summaryItem("Available", value: "\(availableCount)")
                summaryItem("On Memo", value: "\(onMemoCount)")
            } else {
                summaryItem("Sold", value: "\(soldCount)")
            }
            Spacer()
        }
        .font(.caption)
        .foregroundStyle(AppColors.inkMuted)
        .padding(.horizontal)
        .padding(.vertical, AppSpacing.s)
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.m, style: .continuous)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCornerRadius.m, style: .continuous)
                        .strokeBorder(AppColors.cardStroke, lineWidth: 1)
                )
        )
        .padding(.horizontal)
    }

    private func summaryItem(_ label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
            Text(value)
                .fontWeight(.medium)
                .foregroundStyle(AppColors.ink)
        }
    }

    @ViewBuilder
    private var tableContent: some View {
        if allGemstones.isEmpty {
            ContentUnavailableView(
                "No Gemstones",
                systemImage: "diamond",
                description: Text("Add gemstones to see them here.")
            )
             .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background)
        } else if filteredGemstones.isEmpty {
            ContentUnavailableView(
                "No Results",
                systemImage: "magnifyingglass",
                description: Text(viewModel.searchText.isEmpty ? "No stones match the selected filters." : "No stones match \"\(viewModel.searchText)\".")
            )
             .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background)
        } else {
            inventoryTable
        }
    }

    @ViewBuilder
    private var inventoryTable: some View {
        if mode == .sold {
            soldInventoryTable
        } else if showColorColumn {
            currentInventoryTableWithColor
        } else {
            currentInventoryTable
        }
    }

}
