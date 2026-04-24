import SwiftUI
import SwiftData

struct LotInventoryView: View {
    // MARK: - Table Layout

    private static let tableLayout = TableColumnLayout(columns: [
        ColumnDef("lot", weight: 2.0, minWidth: 80),
        ColumnDef("stoneType", weight: 2.0, minWidth: 70),
        ColumnDef("carats", weight: 1.5, minWidth: 60, alignment: .trailing),
        ColumnDef("stones", weight: 1.0, minWidth: 50, alignment: .trailing),
        ColumnDef("avgCost", weight: 1.5, minWidth: 70, alignment: .trailing),
        ColumnDef("sellPrice", weight: 1.5, minWidth: 70, alignment: .trailing),
        ColumnDef("status", weight: 1.5, minWidth: 65),
    ], spacing: AppSpacing.tableColumnGap)

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var allStones: [Gemstone]

    @State var viewModel = LotInventoryViewModel()
    @State private var filterState = InventoryFilterState()
    @State private var showAddLotSheet = false

    // MARK: - Init

    init() {
        _allStones = Query(sort: \Gemstone.sku)
    }

    @State private var showHistorySheet = false
    @State private var historyLot: Gemstone?
    @State private var doubleClickedLot: Gemstone?

    // MARK: - Computed

    private var lots: [Gemstone] {
        allStones.filter { $0.grouping == .lot }
    }

    private var filteredLots: [Gemstone] {
        GemstoneFilterEngine.apply(filterState, to: lots, hint: .lots)
    }

    private var selectedLot: Gemstone? {
        guard let id = viewModel.selectedLotID else { return nil }
        return filteredLots.first { $0.persistentModelID == id }
    }

    private var totalRemainingCarats: Double {
        filteredLots.reduce(0) { $0 + $1.effectiveRemainingCarats }
    }

    private var totalSellValue: Decimal {
        filteredLots.reduce(Decimal.zero) { $0 + $1.sellPrice * Decimal($1.effectiveRemainingCarats) }
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .trailing) {
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    topBar
                    tableContent
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                summaryStrip
            }

            if let lot = selectedLot {
                Color.black.opacity(0.15)
                    .ignoresSafeArea()
                    .onTapGesture { viewModel.selectedLotID = nil }

                lotDetailPanel(lot)
                    .frame(width: 380)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                            .strokeBorder(Color.white.opacity(AppOpacity.subtle), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.4), radius: 20, x: -6)
                    .padding(.vertical, AppSpacing.standard)
                    .padding(.trailing, AppSpacing.standard)
                    .transition(reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: selectedLot?.persistentModelID)
        .sheet(isPresented: $viewModel.showAddQuantitySheet) {
            if let lot = selectedLot {
                addQuantitySheet(lot)
            }
        }
        .sheet(isPresented: $showHistorySheet) {
            if let lot = historyLot {
                lotHistorySheet(lot)
            }
        }
        .sheet(item: $doubleClickedLot) { lot in
            lotFullDetailSheet(lot)
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: AppSpacing.standard) {
                Button("Add Lot", systemImage: "plus.circle.fill") {
                    showAddLotSheet = true
                }
                .buttonStyle(.gradient)
                .controlSize(.small)
                Spacer()
            }
            .padding(.horizontal, AppSpacing.section)
            .padding(.vertical, AppSpacing.compact)
            lotFilterBar
        }
        .sheet(isPresented: $showAddLotSheet) {
            NavigationStack {
                StoneFormView(mode: .intake, defaultGrouping: .lot)
            }
        }
    }

    private var lotFilterBar: some View {
        InventoryFilterBarV2(
            config: .lots,
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
            onClearAll: { filterState.clearAll() }
        )
        .onChange(of: filterState.caratMinText) { _, _ in filterState.syncRangeValues() }
        .onChange(of: filterState.caratMaxText) { _, _ in filterState.syncRangeValues() }
        .onChange(of: filterState.priceMinText) { _, _ in filterState.syncRangeValues() }
        .onChange(of: filterState.priceMaxText) { _, _ in filterState.syncRangeValues() }
    }

    // MARK: - Table

    private var tableContent: some View {
        GeometryReader { geo in
            let widths = Self.tableLayout.widths(for: geo.size.width - 2 * AppSpacing.standard)
            VStack(spacing: 0) {
                tableHeader(widths: widths)
                Divider().background(AppColors.cardStroke)

                if filteredLots.isEmpty {
                    EmptyStateView(
                        icon: "cube.box",
                        title: "No lot stones",
                        subtitle: "Lot inventory will appear here"
                    )
                } else {
                    ScrollView(.vertical) {
                        LazyVStack(spacing: AppSpacing.tight) {
                            ForEach(Array(filteredLots.enumerated()), id: \.element.persistentModelID) { index, lot in
                                lotRow(lot, widths: widths)
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
            sortableHeader("Lot#", key: "sku", width: widths[0], alignment: .leading)
            sortableHeader("Stone Type", key: "type", width: widths[1], alignment: .leading)
            sortableHeader("Carats", key: "carats", width: widths[2], alignment: .trailing)
            sortableHeader("Stones", key: "stones", width: widths[3], alignment: .trailing)
            sortableHeader("Avg Cost/ct", key: "avgCost", width: widths[4], alignment: .trailing)
            sortableHeader("Sell Price", key: "sell", width: widths[5], alignment: .trailing)
            sortableHeader("Status", key: "status", width: widths[6], alignment: .leading)
        }
        .padding(.horizontal, AppSpacing.standard)
        .padding(.vertical, AppSpacing.compact)
    }

    private func sortableHeader(_ title: String, key: String, width: CGFloat, alignment: Alignment) -> TableHeader {
        TableHeader(title: title, width: width, alignment: alignment, isSorted: filterState.sortKey == key, ascending: filterState.sortAscending, onTap: { filterState.toggleSort(key) })
    }

    private func lotRow(_ lot: Gemstone, widths: [CGFloat]) -> some View {
        HoverRow(isSelected: viewModel.selectedLotID == lot.persistentModelID, onTap: {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.15)) {
                if viewModel.selectedLotID == lot.persistentModelID {
                    viewModel.selectedLotID = nil
                } else {
                    viewModel.selectedLotID = lot.persistentModelID
                }
            }
        }) {
            Text(lot.sku)
                .font(AppTypography.mono)
                .foregroundStyle(AppColors.ink)
                .frame(width: widths[0], alignment: .leading)

            StoneTypeBadge(type: lot.stoneType.rawValue)
                .frame(width: widths[1], alignment: .leading)

            Text(String(format: "%.2f", lot.effectiveRemainingCarats))
                .font(AppTypography.mono)
                .foregroundStyle(AppColors.ink)
                .frame(width: widths[2], alignment: .trailing)

            Text(lot.numberOfStones.map { "\($0)" } ?? "—")
                .font(AppTypography.mono)
                .foregroundStyle(AppColors.inkMuted)
                .frame(width: widths[3], alignment: .trailing)

            Text(formattedPrice(averageCostPerCarat(lot), currency: lot.currencyType))
                .font(AppTypography.mono)
                .foregroundStyle(AppColors.inkMuted)
                .frame(width: widths[4], alignment: .trailing)

            Text(formattedPrice(lot.sellPrice, currency: lot.currencyType))
                .font(AppTypography.mono)
                .foregroundStyle(AppColors.ink)
                .frame(width: widths[5], alignment: .trailing)

            lot.status.badge
                .frame(width: widths[6], alignment: .leading)
        }
        .frame(height: 32)
        .onTapGesture(count: 2) {
            doubleClickedLot = lot
        }
    }

    // MARK: - Detail Panel

    private func lotDetailPanel(_ lot: Gemstone) -> some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: AppSpacing.hero) {
                GlassCard(padding: AppSpacing.section) {
                    VStack(alignment: .leading, spacing: AppSpacing.comfortable) {
                        HStack {
                            Text(lot.sku)
                                .font(AppTypography.mono)
                                .foregroundStyle(AppColors.primary)
                            Spacer()
                            StoneTypeBadge(type: lot.stoneType.rawValue)
                        }
                        Text(String(format: "%.2f ct remaining", lot.effectiveRemainingCarats))
                            .font(AppTypography.largeValue)
                            .foregroundStyle(AppColors.ink)
                    }
                }

                GlassCard(padding: AppSpacing.section) {
                    VStack(alignment: .leading, spacing: AppSpacing.comfortable) {
                        SectionHeader(title: "Details")
                        DetailRow(label: "Color", value: lot.color.isEmpty ? "—" : lot.color)
                        DetailRow(label: "Origin", value: lot.origin.isEmpty ? "—" : lot.origin)
                        DetailRow(label: "Treatment", value: lot.treatment.isEmpty ? "—" : lot.treatment)
                        if let size = lot.size, !size.isEmpty {
                            DetailRow(label: "Size Range", value: size)
                        }
                        if let quality = lot.quality, !quality.isEmpty {
                            DetailRow(label: "Quality", value: quality)
                        }
                        if let stones = lot.numberOfStones {
                            DetailRow(label: "Stones", value: "\(stones)")
                        }
                    }
                }

                GlassCard(padding: AppSpacing.section) {
                    VStack(alignment: .leading, spacing: AppSpacing.comfortable) {
                        SectionHeader(title: "Pricing")
                        DetailRow(label: "Avg Cost/ct", value: formattedPrice(averageCostPerCarat(lot), currency: lot.currencyType))
                        DetailRow(label: "Total Cost", value: formattedPrice(averageCostPerCarat(lot) * Decimal(lot.effectiveRemainingCarats), currency: lot.currencyType))
                        DetailRow(label: "Sell/ct", value: formattedPrice(lot.sellPrice, currency: lot.currencyType))
                        DetailRow(label: "Total Sell", value: formattedPrice(lot.sellPrice * Decimal(lot.effectiveRemainingCarats), currency: lot.currencyType))
                    }
                }

                HStack(spacing: AppSpacing.comfortable) {
                    Button("Add Qty", systemImage: "plus.circle.fill") {
                        viewModel.showAddQuantitySheet = true
                    }
                    .buttonStyle(.gradient)
                    .fixedSize()

                    Button {
                        historyLot = lot
                        showHistorySheet = true
                    } label: {
                        Label("History", systemImage: "clock")
                    }
                    .buttonStyle(.outline)
                }
            }
            .padding(AppSpacing.hero)
        }
        .background(AppColors.panelBackground)
    }

    // MARK: - Summary Strip

    private var summaryStrip: some View {
        HStack(spacing: AppSpacing.hero) {
            summaryItem(label: "Total Lots", value: "\(filteredLots.count)")
            summaryItem(label: "Remaining Carats", value: String(format: "%.2f ct", totalRemainingCarats))
            summaryItem(label: "Total Sell Value", value: formattedPrice(totalSellValue))
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

    private func summaryItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.tight) {
            Text(label.uppercased())
                .font(AppTypography.sectionLabel)
                .foregroundStyle(AppColors.inkSubtle)
                .tracking(1)
            Text(value)
                .font(AppTypography.smallValue)
                .foregroundStyle(AppColors.ink)
        }
    }

    // MARK: - Add Quantity Sheet

    private func addQuantitySheet(_ lot: Gemstone) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.hero) {
            Text("Add Quantity to \(lot.sku)")
                .font(AppTypography.heading)
                .foregroundStyle(AppColors.ink)

            VStack(alignment: .leading, spacing: AppSpacing.comfortable) {
                Text("Carats")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.inkSubtle)
                TextField("Carats", value: $viewModel.addCarats, format: .number)
                    .glassField()

                Text("Cost per Carat")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.inkSubtle)
                TextField("Cost/ct", value: $viewModel.addCostPerCarat, format: .number)
                    .glassField()

                Text("Notes")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.inkSubtle)
                TextField("Optional notes", text: $viewModel.addNotes)
                    .glassField()
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    viewModel.resetAddForm()
                }
                .buttonStyle(.outline)

                Button("Add") {
                    do {
                        try viewModel.addQuantity(to: lot, modelContext: modelContext)
                    } catch {
                        AppLogger.data.error("Failed to add quantity: \(error.localizedDescription)")
                    }
                }.buttonStyle(.gradient)
            }
        }
        .padding(AppSpacing.hero)
        .frame(width: 400)
        .appBackground()
    }

    // MARK: - History Sheet

    private func lotHistorySheet(_ lot: Gemstone) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.hero) {
            HStack {
                Text("Lot History - \(lot.sku)")
                    .font(AppTypography.heading)
                    .foregroundStyle(AppColors.ink)
                Spacer()
                Button("Done") {
                    showHistorySheet = false
                }
                .buttonStyle(.outline)
            }

            let transactions = lot.lotTransactions.sorted { $0.date > $1.date }
            if transactions.isEmpty {
                EmptyStateView(icon: "clock", title: "No transactions yet")
            } else {
                ScrollView(.vertical) {
                    LazyVStack(spacing: AppSpacing.comfortable) {
                        ForEach(transactions, id: \.persistentModelID) { tx in
                            GlassCard(padding: AppSpacing.section) {
                                HStack(spacing: AppSpacing.comfortable) {
                                    Image(systemName: tx.type.displayIcon)
                                        .font(AppTypography.body)
                                        .foregroundStyle(transactionColor(tx.type))
                                        .frame(width: 28)

                                    VStack(alignment: .leading, spacing: AppSpacing.tight) {
                                        Text(tx.type.rawValue)
                                            .font(AppTypography.subheading)
                                            .foregroundStyle(AppColors.ink)
                                        Text("\(String(format: "%.2f", tx.carats)) ct @ \(formattedPrice(tx.pricePerCarat))/ct")
                                            .font(AppTypography.body)
                                            .foregroundStyle(AppColors.inkMuted)
                                        if !tx.notes.isEmpty {
                                            Text(tx.notes)
                                                .font(AppTypography.caption)
                                                .foregroundStyle(AppColors.inkSubtle)
                                        }
                                    }

                                    Spacer()

                                    VStack(alignment: .trailing, spacing: AppSpacing.tight) {
                                        Text(formattedPrice(tx.totalPrice))
                                            .font(AppTypography.mono)
                                            .foregroundStyle(AppColors.ink)
                                        Text(formattedDate(tx.date))
                                            .font(AppTypography.caption)
                                            .foregroundStyle(AppColors.inkSubtle)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(AppSpacing.hero)
        .frame(minWidth: 560, minHeight: 400)
        .appBackground()
    }

    // MARK: - Lot Full Detail Sheet (Double-Click)

    private func lotFullDetailSheet(_ lot: Gemstone) -> some View {
        let transactions = lot.lotTransactions.sorted { $0.date > $1.date }
        let totalPieces = transactions.filter { $0.type == .added }.reduce(0.0) { $0 + $1.carats }

        return VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: AppSpacing.tableColumnGap) {
                    HStack(spacing: AppSpacing.comfortable) {
                        Text(lot.sku)
                            .font(AppTypography.heading)
                            .foregroundStyle(AppColors.ink)
                        StoneTypeBadge(type: lot.stoneType.rawValue)
                    }
                    HStack(spacing: AppSpacing.hero) {
                        let dims: String = {
                            if let l = lot.length, let w = lot.width, let h = lot.height {
                                return String(format: "%.2f x %.2f x %.2f", l, w, h)
                            }
                            return "N/A"
                        }()
                        let qualityText: String = {
                            if let q = lot.quality, !q.isEmpty { return q }
                            let parts = [lot.color, lot.clarity].filter { !$0.isEmpty }
                            return parts.isEmpty ? "N/A" : parts.joined(separator: " / ")
                        }()
                        Text("Dimensions: \(dims)")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.inkSubtle)
                        Text("Quality: \(qualityText)")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.inkSubtle)
                        Text("Price: \(formattedPrice(lot.sellPrice))/ct")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.inkSubtle)
                    }
                }
                Spacer()
                Button("Done") { doubleClickedLot = nil }
                    .buttonStyle(.outline)
            }
            .padding(.horizontal, AppSpacing.hero)
            .padding(.vertical, AppSpacing.section)

            Divider().background(AppColors.cardStroke)

            // Info strip
            HStack(spacing: AppSpacing.hero) {
                lotInfoItem(label: "Total Added", value: String(format: "%.2f ct", totalPieces))
                lotInfoItem(label: "Remaining", value: String(format: "%.2f ct", lot.effectiveRemainingCarats))
                lotInfoItem(label: "Avg Cost/ct", value: formattedPrice(averageCostPerCarat(lot)))
                lotInfoItem(label: "Sell/ct", value: formattedPrice(lot.sellPrice))
                Spacer()
            }
            .padding(.horizontal, AppSpacing.hero)
            .padding(.vertical, AppSpacing.comfortable)
            .background(AppColors.cardBackground)

            Divider().background(AppColors.cardStroke)

            // History table
            VStack(spacing: 0) {
                HStack(spacing: AppSpacing.tableColumnGap) {
                    Text("Date")
                        .frame(width: TableColumn.date, alignment: .leading)
                    Text("Action")
                        .frame(width: TableColumn.status, alignment: .leading)
                    Text("Carats")
                        .frame(width: TableColumn.carat, alignment: .trailing)
                    Text("Rate/ct")
                        .frame(width: TableColumn.price, alignment: .trailing)
                    Text("Amount")
                        .frame(width: TableColumn.price, alignment: .trailing)
                    Text("Notes")
                        .frame(width: TableColumn.description, alignment: .leading)
                    Spacer()
                }
                .font(AppTypography.sectionLabel)
                .foregroundStyle(AppColors.inkSubtle)
                .padding(.horizontal, AppSpacing.section)
                .padding(.vertical, AppSpacing.comfortable)

                Divider().background(AppColors.cardStroke)

                if transactions.isEmpty {
                    EmptyStateView(icon: "clock", title: "No lot history yet")
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                } else {
                    ScrollView(.vertical) {
                        LazyVStack(spacing: AppSpacing.tight) {
                            ForEach(transactions, id: \.persistentModelID) { tx in
                                HStack(spacing: AppSpacing.tableColumnGap) {
                                    Text(tx.date.formatted(.dateTime.month(.abbreviated).day().year()))
                                        .font(AppTypography.caption)
                                        .foregroundStyle(AppColors.inkMuted)
                                        .frame(width: TableColumn.date, alignment: .leading)

                                    HStack(spacing: AppSpacing.tableColumnGap) {
                                        Image(systemName: tx.type.displayIcon)
                                            .foregroundStyle(transactionColor(tx.type))
                                            .font(AppTypography.footnote)
                                        Text(tx.type.rawValue)
                                            .foregroundStyle(AppColors.ink)
                                    }
                                    .font(AppTypography.body)
                                    .frame(width: TableColumn.status, alignment: .leading)

                                    Text(String(format: "%.2f", tx.carats))
                                        .font(AppTypography.mono)
                                        .foregroundStyle(AppColors.ink)
                                        .frame(width: TableColumn.carat, alignment: .trailing)

                                    Text(formattedPrice(tx.pricePerCarat))
                                        .font(AppTypography.mono)
                                        .foregroundStyle(AppColors.inkMuted)
                                        .frame(width: TableColumn.price, alignment: .trailing)

                                    Text(formattedPrice(tx.totalPrice))
                                        .font(AppTypography.mono)
                                        .foregroundStyle(AppColors.ink)
                                        .frame(width: TableColumn.price, alignment: .trailing)

                                    Text(tx.notes.isEmpty ? "—" : tx.notes)
                                        .font(AppTypography.caption)
                                        .foregroundStyle(AppColors.inkSubtle)
                                        .lineLimit(1)
                                        .frame(width: TableColumn.description, alignment: .leading)

                                    Spacer()
                                }
                                .padding(.horizontal, AppSpacing.section)
                                .padding(.vertical, AppSpacing.comfortable)
                            }
                        }
                        .padding(.vertical, AppSpacing.standard)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .glassTable()
            .padding(.horizontal, AppSpacing.hero)
            .padding(.bottom, AppSpacing.hero)
            .padding(.top, AppSpacing.comfortable)
        }
        .frame(minWidth: 780, minHeight: 460)
        .appBackground()
    }

    private func lotInfoItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.tight) {
            Text(label.uppercased())
                .font(AppTypography.sectionLabel)
                .foregroundStyle(AppColors.inkSubtle)
                .tracking(1)
            Text(value)
                .font(AppTypography.smallValue)
                .foregroundStyle(AppColors.ink)
        }
    }

    // MARK: - Average Cost

    /// Average cost per carat from the lot's weighted-average cost.
    private func averageCostPerCarat(_ lot: Gemstone) -> Decimal {
        lot.effectiveAverageCost
    }

    // MARK: - Helpers

    private func transactionColor(_ type: LotTransactionType) -> Color {
        switch type {
        case .added:    return AppColors.success
        case .sold:     return AppColors.accentRose
        case .returned: return AppColors.primary
        case .onMemo:   return AppColors.warning
        }
    }

    private func formattedPrice(_ price: Decimal, currency: CurrencyType = .usd) -> String {
        price.asCurrency(currency)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
