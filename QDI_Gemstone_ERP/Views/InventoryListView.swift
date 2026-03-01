import SwiftUI
import SwiftData

enum InventoryListMode {
    case current   /// Non-sold only (available + on memo)
    case sold      /// Sold items only
}

struct InventoryListView: View {
    @Binding var selectedNavigationItem: NavigationItem
    var mode: InventoryListMode = .current
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Gemstone.sku) private var allGemstones: [Gemstone]
    @State private var viewModel = InventoryViewModel()
    @State private var selectedStoneID: PersistentIdentifier?
    @State private var showEditSheet = false
    @State private var showColorColumn = false
    #if DEBUG
    @State private var skuMismatchAlert: String?
    #endif

    private var baseGemstones: [Gemstone] {
        switch mode {
        case .current:
            return allGemstones.filter { $0.effectiveStatus != .sold }
        case .sold:
            return allGemstones.filter { $0.effectiveStatus == .sold }
        }
    }

    private var filteredGemstones: [Gemstone] {
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
            .background(AppColors.background)
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
            Text(mode == .sold ? "Sold Inventory" : "Current Inventory")
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
                Button("Quick Intake") { selectedNavigationItem = .quickIntake }
                Button("Review Queue") { selectedNavigationItem = .reviewQueue }
            }
        }
        .padding()
    }

    private var searchRow: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search by SKU, type, color, clarity, cert no, origin", text: $viewModel.searchText)
                .appSearchField()
        }
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
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: AppSpacing.xs) {
                ForEach(InventoryStoneTypeFilter.allCases, id: \.self) { type in
                    Button {
                        viewModel.stoneTypeFilter = type
                    } label: {
                        Text(type.rawValue)
                            .font(.caption)
                            .padding(.horizontal, AppSpacing.s)
                            .padding(.vertical, 4)
                            .background(viewModel.stoneTypeFilter == type ? AppColors.primary.opacity(0.2) : Color.clear)
                            .foregroundStyle(viewModel.stoneTypeFilter == type ? AppColors.ink : AppColors.inkMuted)
                            .clipShape(Capsule(style: .continuous))
                    }
                    .buttonStyle(.plain)
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
                .foregroundStyle(.secondary)
            }

            Spacer()
            Button(showColorColumn ? "Compact" : "Show Color") {
                showColorColumn.toggle()
            }
            .buttonStyle(.borderless)
            Text("\(filteredGemstones.count) shown")
                .font(.caption)
                .foregroundStyle(.tertiary)
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
                        Button {
                            viewModel.removePill(pill)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, AppSpacing.s)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.08))
                    .cornerRadius(8)
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, AppSpacing.s)
    }

    private var inlineFilterPanel: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            Divider()
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.m) {
                // Shape
                VStack(alignment: .leading, spacing: 4) {
                    Text("Shape")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Any", text: Binding(
                        get: { viewModel.shapeFilter ?? "" },
                        set: { viewModel.shapeFilter = $0.isEmpty ? nil : $0 }
                    ))
                    .appSearchField()
                }

                // Certified
                VStack(alignment: .leading, spacing: 4) {
                    Text("Certified")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("", selection: $viewModel.certifiedFilter) {
                        ForEach(CertifiedFilter.allCases, id: \.self) { f in
                            Text(f.rawValue).tag(f)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }

                // Treatment
                VStack(alignment: .leading, spacing: 4) {
                    Text("Treatment")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Any", text: Binding(
                        get: { viewModel.treatmentFilter ?? "" },
                        set: { viewModel.treatmentFilter = $0.isEmpty ? nil : $0 }
                    ))
                    .appSearchField()
                }

                // Single / Pair / Lot
                VStack(alignment: .leading, spacing: 4) {
                    Text("Single / Pair / Lot")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("", selection: Binding(
                        get: { viewModel.groupingFilter ?? "" },
                        set: { viewModel.groupingFilter = $0.isEmpty ? nil : $0 }
                    )) {
                        Text("Any").tag("")
                        Text("Single").tag("S")
                        Text("Pair").tag("P")
                        Text("Lot").tag("L")
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }

                // Carat min
                VStack(alignment: .leading, spacing: 4) {
                    Text("Carat min")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("0", text: Binding(
                        get: { viewModel.caratMin.map { String(format: "%.2f", $0) } ?? "" },
                        set: { viewModel.caratMin = Double($0) }
                    ))
                    .appSearchField()
                }

                // Carat max
                VStack(alignment: .leading, spacing: 4) {
                    Text("Carat max")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Any", text: Binding(
                        get: { viewModel.caratMax.map { String(format: "%.2f", $0) } ?? "" },
                        set: { viewModel.caratMax = $0.isEmpty ? nil : Double($0) }
                    ))
                    .appSearchField()
                }

                // Sell min
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sell min")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("0", text: Binding(
                        get: { viewModel.sellMin.map { "\($0)" } ?? "" },
                        set: { viewModel.sellMin = Decimal(string: $0) }
                    ))
                    .appSearchField()
                }

                // Sell max
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sell max")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Any", text: Binding(
                        get: { viewModel.sellMax.map { "\($0)" } ?? "" },
                        set: { viewModel.sellMax = Decimal(string: $0) }
                    ))
                    .appSearchField()
                }

                // Diamond-only: Color
                if viewModel.showDiamondFilters {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Color")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("e.g. D-F", text: Binding(
                            get: { viewModel.colorFilter ?? "" },
                            set: { viewModel.colorFilter = $0.isEmpty ? nil : $0 }
                        ))
                        .appSearchField()
                    }
                }

                // Diamond-only: Clarity
                if viewModel.showDiamondFilters {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Clarity")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("e.g. VS1+", text: Binding(
                            get: { viewModel.clarityFilter ?? "" },
                            set: { viewModel.clarityFilter = $0.isEmpty ? nil : $0 }
                        ))
                        .appSearchField()
                    }
                }
            }
            .padding(.horizontal)
            Divider()
        }
        .padding(.vertical, AppSpacing.s)
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
        .foregroundStyle(.secondary)
        .padding(.horizontal)
        .padding(.vertical, AppSpacing.s)
        .background(AppColors.cardBackground.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.m, style: .continuous))
        .padding(.horizontal)
    }

    private func summaryItem(_ label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
            Text(value)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
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

    private func soldToCustomer(for stone: Gemstone) -> String {
        let sku = stone.sku
        var descriptor = FetchDescriptor<LineItem>(
            predicate: #Predicate<LineItem> { item in
                item.invoice != nil && item.gemstone?.sku == sku
            }
        )
        descriptor.fetchLimit = 1
        guard let items = try? modelContext.fetch(descriptor),
              let customer = items.first?.invoice?.customer else { return "—" }
        return customer.displayName
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

    private var soldInventoryTable: some View {
        AppSurfaceCard(padding: AppSpacing.s) {
            Table(filteredGemstones, selection: $selectedStoneID) {
                TableColumn("SKU") { stone in Text(stone.sku).lineLimit(1).truncationMode(.tail) }
                TableColumn("Type") { stone in Text(stone.stoneType.rawValue).lineLimit(1).truncationMode(.tail) }
                TableColumn("Status") { stone in Text(stone.effectiveStatus.rawValue).lineLimit(1).truncationMode(.tail) }
                TableColumn("Sold To") { stone in Text(soldToCustomer(for: stone)).lineLimit(1).truncationMode(.tail) }
                TableColumn("Carat") { stone in Text(String(format: "%.2f", stone.caratWeight)) }
                TableColumn("Color") { stone in Text(stone.color).lineLimit(1).truncationMode(.tail) }
                TableColumn("Sell") { stone in Text(formatCurrency(stone.sellPrice)) }
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            .contextMenu(forSelectionType: PersistentIdentifier.self) { _ in
                Button("Edit...") { showEditSheet = true }
            } primaryAction: { _ in showEditSheet = true }
        }
    }

    private var currentInventoryTableWithColor: some View {
        AppSurfaceCard(padding: AppSpacing.s) {
            Table(filteredGemstones, selection: $selectedStoneID) {
                TableColumn("SKU") { stone in Text(stone.sku).lineLimit(1).truncationMode(.tail) }
                TableColumn("Type") { stone in Text(stone.stoneType.rawValue).lineLimit(1).truncationMode(.tail) }
                TableColumn("Status") { stone in Text(stone.effectiveStatus.rawValue).lineLimit(1).truncationMode(.tail) }
                TableColumn("Carat") { stone in Text(String(format: "%.2f", stone.caratWeight)) }
                TableColumn("Color") { stone in Text(stone.color).lineLimit(1).truncationMode(.tail) }
                TableColumn("Sell") { stone in Text(formatCurrency(stone.sellPrice)) }
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            .contextMenu(forSelectionType: PersistentIdentifier.self) { _ in
                Button("Edit...") { showEditSheet = true }
            } primaryAction: { _ in showEditSheet = true }
        }
    }

    private var currentInventoryTable: some View {
        AppSurfaceCard(padding: AppSpacing.s) {
            Table(filteredGemstones, selection: $selectedStoneID) {
                TableColumn("SKU") { stone in Text(stone.sku).lineLimit(1).truncationMode(.tail) }
                TableColumn("Type") { stone in Text(stone.stoneType.rawValue).lineLimit(1).truncationMode(.tail) }
                TableColumn("Status") { stone in Text(stone.effectiveStatus.rawValue).lineLimit(1).truncationMode(.tail) }
                TableColumn("Carat") { stone in Text(String(format: "%.2f", stone.caratWeight)) }
                TableColumn("Sell") { stone in Text(formatCurrency(stone.sellPrice)) }
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            .contextMenu(forSelectionType: PersistentIdentifier.self) { _ in
                Button("Edit...") { showEditSheet = true }
            } primaryAction: { _ in showEditSheet = true }
        }
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: value as NSDecimalNumber) ?? "$0"
    }
}
