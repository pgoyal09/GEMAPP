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
    @State private var stoneTypeFilter: StoneType?
    @State private var statusFilter: GemstoneStatus?
    @State private var shapeFilter: String?
    @State private var groupingFilter: StoneGrouping?
    @State private var colorFilter: String?
    @State private var clarityFilter: String?
    @State private var cutFilter: String?
    @State private var originFilter: String?
    @State private var treatmentFilter: String?
    @State private var labFilter: String?
    @State private var caratMin: Double?
    @State private var caratMax: Double?
    @State private var caratMinText: String = ""
    @State private var caratMaxText: String = ""
    @State private var priceMin: Decimal?
    @State private var priceMax: Decimal?
    @State private var priceMinText: String = ""
    @State private var priceMaxText: String = ""
    @State private var searchFieldFocusRequest = false

    // MARK: - Init

    init() {
        _allStones = Query(sort: \Gemstone.sku)
    }

    @State private var showHistorySheet = false
    @State private var historyLot: Gemstone?
    @State private var doubleClickedLot: Gemstone?
    @State private var sortKey: String = "sku"
    @State private var sortAscending: Bool = true

    // MARK: - Computed

    private var lots: [Gemstone] {
        allStones.filter { $0.grouping == .lot }
    }

    private var filteredLots: [Gemstone] {
        var result = viewModel.filtered(from: lots)
        // Status
        if let s = statusFilter { result = result.filter { $0.status == s } }
        // Stone Type
        if let type = stoneTypeFilter { result = result.filter { $0.stoneType == type } }
        // Shape
        if let s = shapeFilter, !s.isEmpty {
            if s == "Other" {
                let top = ["round","cushion","oval","pear","emerald","princess","marquise"]
                result = result.filter { !top.contains($0.shape.lowercased()) }
            } else {
                result = result.filter { $0.shape.lowercased().contains(s.lowercased()) }
            }
        }
        // Color
        if let c = colorFilter, !c.isEmpty {
            result = result.filter { $0.color.lowercased().contains(c.lowercased()) }
        }
        // Lab
        if let l = labFilter, !l.isEmpty {
            if l == "None" { result = result.filter { $0.certLab.isEmpty } }
            else { result = result.filter { $0.certLab.uppercased() == l.uppercased() } }
        }
        // Carat range
        if let min = caratMin { result = result.filter { $0.effectiveRemainingCarats >= min } }
        if let max = caratMax { result = result.filter { $0.effectiveRemainingCarats <= max } }
        // Price range
        if let min = priceMin { result = result.filter { $0.sellPrice >= min } }
        if let max = priceMax { result = result.filter { $0.sellPrice <= max } }
        return sortedLots(result)
    }

    private var activeFilterCount: Int {
        var count = 0
        if statusFilter != nil { count += 1 }
        if stoneTypeFilter != nil { count += 1 }
        if shapeFilter != nil { count += 1 }
        if colorFilter != nil { count += 1 }
        if labFilter != nil { count += 1 }
        if caratMin != nil || caratMax != nil { count += 1 }
        if priceMin != nil || priceMax != nil { count += 1 }
        return count
    }

    private func sortedLots(_ lots: [Gemstone]) -> [Gemstone] {
        lots.sorted { a, b in
            let asc: Bool
            switch sortKey {
            case "type": asc = a.stoneType.rawValue.localizedCompare(b.stoneType.rawValue) == .orderedAscending
            case "carats": asc = a.effectiveRemainingCarats < b.effectiveRemainingCarats
            case "stones": asc = (a.numberOfStones ?? 0) < (b.numberOfStones ?? 0)
            case "avgCost": asc = averageCostPerCarat(a) < averageCostPerCarat(b)
            case "sell": asc = a.sellPrice < b.sellPrice
            case "status": asc = a.status.rawValue.localizedCompare(b.status.rawValue) == .orderedAscending
            default: asc = a.sku.localizedCompare(b.sku) == .orderedAscending
            }
            return sortAscending ? asc : !asc
        }
    }

    private func toggleSort(_ key: String) {
        if sortKey == key { sortAscending.toggle() }
        else { sortKey = key; sortAscending = true }
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
            lotFilterBar
        }
    }

    private var lotFilterBar: some View {
        InventoryFilterBarV2(
            config: .lots,
            statusFilter: $statusFilter,
            shapeFilter: $shapeFilter,
            groupingFilter: $groupingFilter,
            colorFilter: $colorFilter,
            clarityFilter: $clarityFilter,
            cutFilter: $cutFilter,
            originFilter: $originFilter,
            treatmentFilter: $treatmentFilter,
            stoneTypeFilter: $stoneTypeFilter,
            caratMinText: $caratMinText,
            caratMaxText: $caratMaxText,
            priceMinText: $priceMinText,
            priceMaxText: $priceMaxText,
            labFilter: $labFilter,
            searchText: $viewModel.searchText,
            searchFieldFocusRequest: $searchFieldFocusRequest,
            onClearAll: clearAllLotFilters
        )
        .onChange(of: caratMinText) { _, val in caratMin = Double(val) }
        .onChange(of: caratMaxText) { _, val in caratMax = Double(val) }
        .onChange(of: priceMinText) { _, val in priceMin = Decimal(string: val) }
        .onChange(of: priceMaxText) { _, val in priceMax = Decimal(string: val) }
    }

    private func clearAllLotFilters() {
        statusFilter = nil; shapeFilter = nil; groupingFilter = nil
        stoneTypeFilter = nil; colorFilter = nil; clarityFilter = nil
        cutFilter = nil; originFilter = nil; treatmentFilter = nil
        labFilter = nil; caratMin = nil; caratMax = nil
        priceMin = nil; priceMax = nil
        caratMinText = ""; caratMaxText = ""
        priceMinText = ""; priceMaxText = ""
        viewModel.searchText = ""
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
        TableHeader(title: title, width: width, alignment: alignment, isSorted: sortKey == key, ascending: sortAscending, onTap: { toggleSort(key) })
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

            statusBadge(for: lot.status)
                .frame(width: widths[6], alignment: .leading)
        }
        .frame(height: 32)
        .onTapGesture(count: 2) {
            doubleClickedLot = lot
        }
    }

    private func statusBadge(for status: GemstoneStatus) -> StatusBadge {
        switch status {
        case .available:    return StatusBadge(title: "Available", tone: .success)
        case .onMemo:       return StatusBadge(title: "On Memo", tone: .warning)
        case .sold:         return StatusBadge(title: "Sold", tone: .accent)
        case .atLab:        return StatusBadge(title: "At Lab", tone: .info)
        case .reserved:     return StatusBadge(title: "Reserved", tone: .danger)
        case .inTransit:    return StatusBadge(title: "In Transit", tone: .violet)
        case .consignment:  return StatusBadge(title: "Consignment", tone: .neutral)
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
