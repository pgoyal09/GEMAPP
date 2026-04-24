import SwiftUI
import SwiftData

struct SoldInventoryView: View {
    // MARK: - Table Layout

    private static let tableLayout = TableColumnLayout(columns: [
        ColumnDef("sku", weight: 2.0, minWidth: 80),
        ColumnDef("stoneType", weight: 1.5, minWidth: 60),
        ColumnDef("carats", weight: 1.2, minWidth: 55, alignment: .trailing),
        ColumnDef("cost", weight: 1.5, minWidth: 70, alignment: .trailing),
        ColumnDef("soldPrice", weight: 1.5, minWidth: 70, alignment: .trailing),
        ColumnDef("margin", weight: 1.2, minWidth: 60, alignment: .trailing),
        ColumnDef("customer", weight: 2.5, minWidth: 100),
        ColumnDef("date", weight: 1.5, minWidth: 70),
    ], spacing: AppSpacing.tableColumnGap)

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Query private var allStones: [Gemstone]

    init() {
        _allStones = Query(sort: \Gemstone.createdAt, order: .reverse)
    }

    @State private var filterState: InventoryFilterState = {
        let state = InventoryFilterState()
        state.statusFilter = .sold
        return state
    }()
    @State private var selectedStoneID: PersistentIdentifier?
    @State private var showEditSheet = false
    @State private var editingStone: Gemstone?
    @State private var doubleClickedStone: Gemstone?

    // MARK: - Sold-Specific UI State

    @State private var typeToggle: SoldTypeToggle = .all
    @State private var showAdvancedFilters = false

    enum SoldTypeToggle: String, CaseIterable {
        case all = "All"
        case diamonds = "Diamonds"
        case gemstones = "Gemstones"
        case lots = "Lots"
    }

    // MARK: - Computed

    private var uniqueCustomers: [String] {
        let names = allStones.filter { $0.status == .sold }
            .compactMap { $0.memo?.customer?.displayName }
        return Array(Set(names)).sorted()
    }

    private var soldHint: GemstoneFilterEngine.ScreenHint {
        .sold(customerName: { customerName(for: $0) })
    }

    private var filteredStones: [Gemstone] {
        var base = allStones.filter { $0.status == .sold }

        switch typeToggle {
        case .all: break
        case .diamonds: base = base.filter { $0.stoneType == .diamond && $0.grouping != .lot }
        case .gemstones: base = base.filter { $0.stoneType != .diamond && $0.grouping != .lot }
        case .lots: base = base.filter { $0.grouping == .lot }
        }

        return GemstoneFilterEngine.apply(filterState, to: base, hint: soldHint)
    }

    private var selectedStone: Gemstone? {
        guard let id = selectedStoneID else { return nil }
        return filteredStones.first { $0.persistentModelID == id }
    }

    private func customerName(for stone: Gemstone) -> String {
        stone.memo?.customer?.displayName ?? "—"
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: AppSpacing.tableColumnGap) {
                VStack(spacing: 0) {
                    topBar
                    tableContent
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if let stone = selectedStone {
                    Divider().background(AppColors.cardStroke)
                    GemstoneDetailPanel(gemstone: stone, onEdit: {
                        editingStone = stone
                        showEditSheet = true
                    })
                    .frame(minWidth: 260, idealWidth: 296, maxWidth: 350)
                }
            }

            summaryFooter
        }
        .animation(reduceMotion ? nil : AppAnimation.sheetSpring, value: selectedStone?.persistentModelID)
        .sheet(isPresented: $showEditSheet) {
            if let stone = editingStone {
                StoneFormView(mode: .edit(stone))
            }
        }
        .sheet(item: $doubleClickedStone) { stone in
            soldStoneDetailSheet(stone)
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        VStack(spacing: AppSpacing.comfortable) {
            HStack(spacing: AppSpacing.comfortable) {
                GlassSearchField(text: Binding(get: { filterState.searchText }, set: { filterState.searchText = $0 }), placeholder: "Search sold stones...")
                    .frame(maxWidth: 320)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.standard) {
                        ForEach(SoldTypeToggle.allCases, id: \.rawValue) { toggle in
                            FilterPill(title: toggle.rawValue, isActive: typeToggle == toggle) {
                                typeToggle = toggle
                            }
                            .fixedSize()
                        }
                    }
                }

                Spacer()

                Button {
                    withAnimation { showAdvancedFilters.toggle() }
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.title3)
                            .foregroundStyle(showAdvancedFilters ? AppColors.primary : AppColors.inkMuted)
                        if filterState.activeFilterCount > 0 {
                            Text("\(filterState.activeFilterCount)")
                                .font(AppTypography.tinyLabel)
                                .foregroundStyle(.white)
                                .frame(width: 14, height: 14)
                                .background(Circle().fill(AppColors.primary))
                                .offset(x: 4, y: -4)
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            InventoryFilterBarV2(
                config: .inventory,
                statusFilter: Binding(get: { filterState.statusFilter }, set: { filterState.statusFilter = $0 }),
                shapeFilter: Binding(get: { filterState.shapeFilter }, set: { filterState.shapeFilter = $0 }),
                groupingFilter: Binding(get: { filterState.groupingFilter }, set: { filterState.groupingFilter = $0 }),
                colorFilter: Binding(get: { filterState.colorFilter }, set: { filterState.colorFilter = $0 }),
                clarityFilter: Binding(get: { filterState.clarityFilter }, set: { filterState.clarityFilter = $0 }),
                cutFilter: Binding(get: { filterState.cutFilter }, set: { filterState.cutFilter = $0 }),
                originFilter: Binding(get: { filterState.originFilter }, set: { filterState.originFilter = $0 }),
                treatmentFilter: Binding(get: { filterState.treatmentFilter }, set: { filterState.treatmentFilter = $0 }),
                stoneTypeFilter: Binding(get: { filterState.stoneTypeFilter }, set: { filterState.stoneTypeFilter = $0 }),
                caratMinText: Binding(get: { filterState.caratMinText }, set: { filterState.caratMinText = $0 }),
                caratMaxText: Binding(get: { filterState.caratMaxText }, set: { filterState.caratMaxText = $0 }),
                priceMinText: Binding(get: { filterState.priceMinText }, set: { filterState.priceMinText = $0 }),
                priceMaxText: Binding(get: { filterState.priceMaxText }, set: { filterState.priceMaxText = $0 }),
                labFilter: Binding(get: { filterState.labFilter }, set: { filterState.labFilter = $0 }),
                searchText: Binding(get: { filterState.searchText }, set: { filterState.searchText = $0 }),
                searchFieldFocusRequest: Binding(get: { filterState.searchFieldFocusRequest }, set: { filterState.searchFieldFocusRequest = $0 }),
                onClearAll: { filterState.clearAll(defaultStatus: .sold) }
            )
            .onChange(of: filterState.caratMinText) { _, _ in filterState.syncRangeValues() }
            .onChange(of: filterState.caratMaxText) { _, _ in filterState.syncRangeValues() }
            .onChange(of: filterState.priceMinText) { _, _ in filterState.syncRangeValues() }
            .onChange(of: filterState.priceMaxText) { _, _ in filterState.syncRangeValues() }

            if filterState.activeFilterCount > 0 {
                HStack(spacing: AppSpacing.standard) {
                    if !filterState.customerFilter.isEmpty {
                        filterChip("Customer: \(filterState.customerFilter)") { filterState.customerFilter = "" }
                    }
                    if filterState.stoneTypeFilter != nil {
                        filterChip("Type: \(filterState.stoneTypeFilter!.rawValue)") { filterState.stoneTypeFilter = nil }
                    }
                    if filterState.dateFrom != nil || filterState.dateTo != nil {
                        filterChip("Date range") { filterState.dateFrom = nil; filterState.dateTo = nil }
                    }
                    if filterState.caratMin != nil || filterState.caratMax != nil {
                        filterChip("Carats") { filterState.caratMin = nil; filterState.caratMax = nil; filterState.caratMinText = ""; filterState.caratMaxText = "" }
                    }
                    if filterState.priceMin != nil || filterState.priceMax != nil {
                        filterChip("Price") { filterState.priceMin = nil; filterState.priceMax = nil; filterState.priceMinText = ""; filterState.priceMaxText = "" }
                    }
                    Spacer()
                    Button("Clear all") {
                        filterState.clearAll(defaultStatus: .sold)
                    }
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.primary)
                }
            }
        }
        .padding(.horizontal, AppSpacing.hero)
        .padding(.vertical, AppSpacing.section)
    }

    // MARK: - Table

    private var tableContent: some View {
        GeometryReader { geo in
            let widths = Self.tableLayout.widths(for: geo.size.width - 2 * AppSpacing.standard)
            VStack(spacing: 0) {
                tableHeader(widths: widths)
                Divider().background(AppColors.cardStroke)
                if filteredStones.isEmpty {
                    EmptyStateView(icon: "tag.slash", title: "No sold stones", subtitle: "Sold inventory will appear here")
                        .frame(maxWidth: .infinity)
                } else {
                    ScrollView(.vertical) {
                        LazyVStack(spacing: AppSpacing.tight) {
                            ForEach(Array(filteredStones.enumerated()), id: \.element.persistentModelID) { index, stone in
                                stoneRow(stone, widths: widths)
                                    .staggeredRow(index: index, reduceMotion: reduceMotion)
                            }
                        }
                        .padding(.vertical, AppSpacing.standard)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .glassTable()
        .padding(.horizontal, AppSpacing.hero)
        .padding(.bottom, AppSpacing.comfortable)
    }

    private func tableHeader(widths: [CGFloat]) -> some View {
        HStack(spacing: AppSpacing.tableColumnGap) {
            sortableHeader("SKU", key: "sku", width: widths[0], alignment: .leading)
            sortableHeader("Stone Type", key: "type", width: widths[1], alignment: .leading)
            sortableHeader("Carats", key: "carat", width: widths[2], alignment: .trailing)
            sortableHeader("Cost", key: "cost", width: widths[3], alignment: .trailing)
            sortableHeader("Sold Price", key: "sold", width: widths[4], alignment: .trailing)
            sortableHeader("Margin%", key: "margin", width: widths[5], alignment: .trailing)
            sortableHeader("Customer", key: "customer", width: widths[6], alignment: .leading)
            sortableHeader("Date", key: "date", width: widths[7], alignment: .leading)
        }
        .padding(.horizontal, AppSpacing.standard)
        .padding(.vertical, AppSpacing.compact)
    }

    private func sortableHeader(_ title: String, key: String, width: CGFloat, alignment: Alignment) -> TableHeader {
        TableHeader(title: title, width: width, alignment: alignment, isSorted: filterState.sortKey == key, ascending: filterState.sortAscending, onTap: { filterState.toggleSort(key) })
    }

    private func stoneRow(_ stone: Gemstone, widths: [CGFloat]) -> some View {
        HoverRow(isSelected: selectedStoneID == stone.persistentModelID, onTap: {
            selectedStoneID = selectedStoneID == stone.persistentModelID ? nil : stone.persistentModelID
        }) {
            Text(stone.sku)
                .font(AppTypography.mono)
                .foregroundStyle(AppColors.ink)
                .lineLimit(1)
                .frame(width: widths[0], alignment: .leading)

            StoneTypeBadge(type: stone.stoneType.rawValue)
                .frame(width: widths[1], alignment: .leading)

            Text(String(format: "%.2f", stone.caratWeight))
                .font(AppTypography.mono)
                .foregroundStyle(AppColors.ink)
                .frame(width: widths[2], alignment: .trailing)

            Text(stone.costPrice.asCurrency(stone.currencyType))
                .font(AppTypography.mono)
                .foregroundStyle(AppColors.inkMuted)
                .frame(width: widths[3], alignment: .trailing)

            Text(stone.sellPrice.asCurrency(stone.currencyType))
                .font(AppTypography.mono)
                .foregroundStyle(AppColors.ink)
                .frame(width: widths[4], alignment: .trailing)

            Text(marginText(stone))
                .font(AppTypography.mono)
                .foregroundStyle(marginColor(stone))
                .frame(width: widths[5], alignment: .trailing)

            Text(customerName(for: stone))
                .font(AppTypography.body)
                .foregroundStyle(AppColors.ink)
                .lineLimit(1)
                .frame(width: widths[6], alignment: .leading)

            Text(stone.createdAt.formatted(.dateTime.month(.abbreviated).day().year()))
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.inkMuted)
                .frame(width: widths[7], alignment: .leading)
        }
        .frame(height: 32)
        .onTapGesture(count: 2) {
            doubleClickedStone = stone
        }
    }

    // MARK: - Summary

    private var summaryFooter: some View {
        let stones = filteredStones
        let totalCarats = stones.reduce(0.0) { $0 + $1.caratWeight }
        let totalSell = stones.reduce(Decimal.zero) { $0 + $1.sellPrice * Decimal($1.caratWeight) }
        let totalCost = stones.reduce(Decimal.zero) { $0 + $1.costPrice * Decimal($1.caratWeight) }
        let totalMargin = totalSell > 0 ? ((totalSell - totalCost) / totalSell) * 100 : 0
        return HStack(spacing: AppSpacing.hero) {
            Text("\(stones.count) sold").font(AppTypography.caption.bold()).foregroundStyle(AppColors.ink)
            Text("Total: \(String(format: "%.2f", totalCarats)) ct").font(AppTypography.caption).foregroundStyle(AppColors.inkMuted)
            Text("Revenue: \(totalSell.asCurrency)").font(AppTypography.caption).foregroundStyle(AppColors.inkMuted)
            Text("Margin: \(String(format: "%.1f", NSDecimalNumber(decimal: totalMargin).doubleValue))%").font(AppTypography.caption).foregroundStyle(AppColors.success)
            Spacer()
        }
        .padding(.horizontal, AppSpacing.hero).padding(.vertical, AppSpacing.comfortable)
        .background(AppColors.cardBackground)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppColors.cardStroke)
                .frame(height: 1)
        }
    }

    // MARK: - Sold Stone Detail Sheet (Double-Click)

    private func soldStoneDetailSheet(_ stone: Gemstone) -> some View {
        let margin = stone.sellPrice - stone.costPrice
        let marginPct: Decimal = stone.costPrice > 0 ? (margin / stone.costPrice) * 100 : 0
        let totalSold = stone.sellPrice * Decimal(stone.caratWeight)
        let totalCost = stone.costPrice * Decimal(stone.caratWeight)
        let totalMargin = totalSold - totalCost

        let soldInfo: (customer: String, ref: String) = {
            for event in stone.events where event.eventType == .sold {
                // Try to find from line items
            }
            if let memo = stone.memo {
                let customerName = memo.customer?.displayName ?? "—"
                return (customerName, "M-\(memo.referenceNumber)")
            }
            return (stone.currentLocation, "—")
        }()

        let history = stone.events.sorted { $0.date > $1.date }

        return VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: AppSpacing.tableColumnGap) {
                    HStack(spacing: AppSpacing.comfortable) {
                        Text(stone.sku)
                            .font(AppTypography.heading)
                            .foregroundStyle(AppColors.ink)
                        StoneTypeBadge(type: stone.stoneType.rawValue)
                        StatusBadge(title: "Sold", tone: .success)
                    }
                }
                Spacer()
                Button("Done") { doubleClickedStone = nil }
                    .buttonStyle(.outline)
            }
            .padding(.horizontal, AppSpacing.hero)
            .padding(.vertical, AppSpacing.section)

            Divider().background(AppColors.cardStroke)

            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: AppSpacing.hero) {
                    // Stone details + pricing side by side
                    HStack(alignment: .top, spacing: AppSpacing.hero) {
                        // Stone details card
                        GlassCard(padding: AppSpacing.section) {
                            VStack(alignment: .leading, spacing: AppSpacing.comfortable) {
                                SectionHeader(title: "Stone Details")
                                DetailRow(label: "Shape", value: stone.shape.isEmpty ? "—" : stone.shape)
                                DetailRow(label: "Weight", value: String(format: "%.2f ct", stone.caratWeight))
                                DetailRow(label: "Color", value: stone.color.isEmpty ? "—" : stone.color)
                                DetailRow(label: "Clarity", value: stone.clarity.isEmpty ? "—" : stone.clarity)
                                if let l = stone.length, let w = stone.width, let h = stone.height {
                                    DetailRow(label: "Dimensions", value: String(format: "%.2f x %.2f x %.2f mm", l, w, h))
                                }
                                DetailRow(label: "Origin", value: stone.origin.isEmpty ? "—" : stone.origin)
                            }
                        }
                        .frame(maxWidth: .infinity)

                        // Pricing card
                        GlassCard(padding: AppSpacing.section) {
                            VStack(alignment: .leading, spacing: AppSpacing.comfortable) {
                                SectionHeader(title: "Pricing")
                                DetailRow(label: "Cost/ct", value: stone.costPrice.asCurrency(stone.currencyType))
                                DetailRow(label: "Sell/ct", value: stone.sellPrice.asCurrency(stone.currencyType))
                                DetailRow(label: "Total Cost", value: totalCost.asCurrency(stone.currencyType))
                                DetailRow(label: "Total Sold", value: totalSold.asCurrency(stone.currencyType))

                                Divider().background(AppColors.cardStroke)

                                HStack {
                                    Text("Margin")
                                        .font(AppTypography.caption)
                                        .foregroundStyle(AppColors.inkSubtle)
                                        .frame(width: 110, alignment: .leading)
                                    Text("\(totalMargin.asCurrency) (\(String(format: "%.1f", NSDecimalNumber(decimal: marginPct).doubleValue))%)")
                                        .font(AppTypography.body.weight(.semibold))
                                        .foregroundStyle(margin >= 0 ? AppColors.success : AppColors.danger)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }

                    // Sold to card
                    GlassCard(padding: AppSpacing.section) {
                        VStack(alignment: .leading, spacing: AppSpacing.comfortable) {
                            SectionHeader(title: "Sold To")
                            DetailRow(label: "Customer", value: soldInfo.customer)
                            DetailRow(label: "Reference", value: soldInfo.ref)
                        }
                    }

                    // History table
                    VStack(alignment: .leading, spacing: AppSpacing.comfortable) {
                        SectionHeader(title: "Stone History")

                        VStack(spacing: 0) {
                            HStack(spacing: AppSpacing.tableColumnGap) {
                                Text("Date")
                                    .frame(width: TableColumn.date, alignment: .leading)
                                Text("Action")
                                    .frame(width: TableColumn.description, alignment: .leading)
                                Spacer()
                            }
                            .font(AppTypography.sectionLabel)
                            .foregroundStyle(AppColors.inkSubtle)
                            .padding(.horizontal, AppSpacing.section)
                            .padding(.vertical, AppSpacing.comfortable)

                            Divider().background(AppColors.cardStroke)

                            if history.isEmpty {
                                Text("No history events")
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.inkSubtle)
                                    .padding(AppSpacing.section)
                            } else {
                                ForEach(history, id: \.persistentModelID) { event in
                                    HStack(spacing: AppSpacing.tableColumnGap) {
                                        Text(event.date.formatted(.dateTime.month(.abbreviated).day().year()))
                                            .font(AppTypography.caption)
                                            .foregroundStyle(AppColors.inkMuted)
                                            .frame(width: TableColumn.date, alignment: .leading)

                                        Text(event.eventDescription)
                                            .font(AppTypography.body)
                                            .foregroundStyle(AppColors.ink)
                                            .lineLimit(1)
                                            .frame(width: TableColumn.description, alignment: .leading)

                                        Spacer()
                                    }
                                    .padding(.horizontal, AppSpacing.section)
                                    .padding(.vertical, AppSpacing.comfortable)
                                }
                            }
                        }
                        .glassTable()
                    }
                }
                .padding(AppSpacing.hero)
            }
        }
        .frame(minWidth: 740, minHeight: 520)
        .appBackground()
    }


    // MARK: - Helpers

    private func marginText(_ stone: Gemstone) -> String {
        guard stone.costPrice > 0 else { return "—" }
        let margin = ((stone.sellPrice - stone.costPrice) / stone.costPrice) * 100
        return String(format: "%.1f%%", NSDecimalNumber(decimal: margin).doubleValue)
    }

    private func marginColor(_ stone: Gemstone) -> Color {
        guard stone.costPrice > 0 else { return AppColors.inkMuted }
        return stone.sellPrice >= stone.costPrice ? AppColors.success : AppColors.danger
    }

    private func filterChip(_ label: String, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: AppSpacing.tableColumnGap) {
            Text(label)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.ink)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(AppTypography.smallValue)
                    .foregroundStyle(AppColors.inkSubtle)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(AppColors.cardElevated))
    }
}
