import SwiftUI
import SwiftData

struct LotInventoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var allStones: [Gemstone]

    @State var viewModel = LotInventoryViewModel()

    // MARK: - Init

    init() {
        // SwiftData #Predicate does not support custom enum types as captured constants.
        // Fetch all and filter in computed property instead.
        _allStones = Query(sort: \Gemstone.sku)
    }
    @State private var showHistorySheet = false
    @State private var historyLot: Gemstone?
    @State private var sortKey: String = "sku"
    @State private var sortAscending: Bool = true

    // MARK: - Computed

    private var lots: [Gemstone] {
        allStones.filter { $0.grouping == .lot }
    }

    private var filteredLots: [Gemstone] {
        sortedLots(viewModel.filtered(from: lots))
    }

    private func sortedLots(_ lots: [Gemstone]) -> [Gemstone] {
        lots.sorted { a, b in
            let asc: Bool
            switch sortKey {
            case "type": asc = a.stoneType.rawValue.localizedCompare(b.stoneType.rawValue) == .orderedAscending
            case "remaining": asc = a.effectiveRemainingCarats < b.effectiveRemainingCarats
            case "avgCost": asc = a.effectiveAverageCost < b.effectiveAverageCost
            case "sell": asc = a.sellPrice < b.sellPrice
            case "value": asc = (a.sellPrice * Decimal(a.effectiveRemainingCarats)) < (b.sellPrice * Decimal(b.effectiveRemainingCarats))
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
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                VStack(spacing: 0) {
                    topBar
                    tableContent
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if let lot = selectedLot {
                    Divider().background(AppColors.cardStroke)
                    lotDetailPanel(lot)
                        .frame(width: 296)
                }
            }

            summaryStrip
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
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: AppSpacing.comfortable) {
            GlassSearchField(text: $viewModel.searchText, placeholder: "Search lots...")
                .frame(maxWidth: 320)

            Spacer()
        }
        .padding(.horizontal, AppSpacing.hero)
        .padding(.vertical, AppSpacing.section)
    }

    // MARK: - Table

    private var tableContent: some View {
        VStack(spacing: 0) {
            tableHeader
            Divider().background(AppColors.cardStroke)

            if filteredLots.isEmpty {
                EmptyStateView(
                    icon: "cube.box",
                    title: "No lot stones",
                    subtitle: "Lot inventory will appear here"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(filteredLots.enumerated()), id: \.element.persistentModelID) { index, lot in
                            lotRow(lot)
                                .staggeredRow(index: index, reduceMotion: reduceMotion)
                        }
                    }
                    .padding(.vertical, AppSpacing.standard)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .glassTable()
        .padding(.horizontal, AppSpacing.hero)
        .padding(.bottom, AppSpacing.comfortable)
    }

    private var tableHeader: some View {
        HStack(spacing: 0) {
            sortableHeader("SKU", key: "sku", width: TableColumn.sku, alignment: .leading)
            sortableHeader("Type", key: "type", width: TableColumn.type, alignment: .leading)
            sortableHeader("Remaining ct", key: "remaining", width: TableColumn.carat + 20, alignment: .trailing)
            sortableHeader("Avg Cost/ct", key: "avgCost", width: TableColumn.price, alignment: .trailing)
            sortableHeader("Sell/ct", key: "sell", width: TableColumn.price, alignment: .trailing)
            sortableHeader("Total Value", key: "value", width: TableColumn.price, alignment: .trailing)
        }
        .padding(.horizontal, AppSpacing.section)
        .padding(.vertical, AppSpacing.comfortable)
    }

    private func sortableHeader(_ title: String, key: String, width: CGFloat, alignment: Alignment) -> TableHeader {
        TableHeader(title: title, width: width, alignment: alignment, isSorted: sortKey == key, ascending: sortAscending, onTap: { toggleSort(key) })
    }

    private func lotRow(_ lot: Gemstone) -> some View {
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
                .frame(minWidth: TableColumn.sku, maxWidth: .infinity, alignment: .leading)

            StoneTypeBadge(type: lot.stoneType.rawValue)
                .frame(minWidth: TableColumn.type, maxWidth: .infinity, alignment: .leading)

            Text(String(format: "%.2f", lot.effectiveRemainingCarats))
                .font(AppTypography.mono)
                .foregroundStyle(AppColors.ink)
                .frame(minWidth: TableColumn.carat + 20, maxWidth: .infinity, alignment: .trailing)

            Text(formattedPrice(lot.effectiveAverageCost))
                .font(AppTypography.mono)
                .foregroundStyle(AppColors.inkMuted)
                .frame(minWidth: TableColumn.price, maxWidth: .infinity, alignment: .trailing)

            Text(formattedPrice(lot.sellPrice))
                .font(AppTypography.mono)
                .foregroundStyle(AppColors.ink)
                .frame(minWidth: TableColumn.price, maxWidth: .infinity, alignment: .trailing)

            Text(formattedPrice(lot.sellPrice * Decimal(lot.effectiveRemainingCarats)))
                .font(AppTypography.mono)
                .foregroundStyle(AppColors.success)
                .frame(minWidth: TableColumn.price, maxWidth: .infinity, alignment: .trailing)
        }
    }

    // MARK: - Detail Panel

    private func lotDetailPanel(_ lot: Gemstone) -> some View {
        ScrollView {
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
                        DetailRow(label: "Color", value: lot.color.isEmpty ? "--" : lot.color)
                        DetailRow(label: "Origin", value: lot.origin.isEmpty ? "--" : lot.origin)
                        DetailRow(label: "Treatment", value: lot.treatment.isEmpty ? "--" : lot.treatment)
                        if let size = lot.size, !size.isEmpty {
                            DetailRow(label: "Size Range", value: size)
                        }
                        if let quality = lot.quality, !quality.isEmpty {
                            DetailRow(label: "Quality", value: quality)
                        }
                    }
                }

                GlassCard(padding: AppSpacing.section) {
                    VStack(alignment: .leading, spacing: AppSpacing.comfortable) {
                        SectionHeader(title: "Pricing")
                        DetailRow(label: "Avg Cost/ct", value: formattedPrice(lot.effectiveAverageCost))
                        DetailRow(label: "Total Cost", value: formattedPrice(lot.effectiveAverageCost * Decimal(lot.effectiveRemainingCarats)))
                        DetailRow(label: "Sell/ct", value: formattedPrice(lot.sellPrice))
                        DetailRow(label: "Total Sell", value: formattedPrice(lot.sellPrice * Decimal(lot.effectiveRemainingCarats)))
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
        VStack(alignment: .leading, spacing: 2) {
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
                ScrollView {
                    LazyVStack(spacing: AppSpacing.comfortable) {
                        ForEach(transactions, id: \.persistentModelID) { tx in
                            GlassCard(padding: AppSpacing.section) {
                                HStack(spacing: AppSpacing.comfortable) {
                                    Image(systemName: tx.type.displayIcon)
                                        .font(AppTypography.body)
                                        .foregroundStyle(transactionColor(tx.type))
                                        .frame(width: 28)

                                    VStack(alignment: .leading, spacing: 2) {
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

                                    VStack(alignment: .trailing, spacing: 2) {
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

    // MARK: - Helpers

    private func transactionColor(_ type: LotTransactionType) -> Color {
        switch type {
        case .added:    return AppColors.success
        case .sold:     return AppColors.accentRose
        case .returned: return AppColors.primary
        case .onMemo:   return AppColors.warning
        }
    }

    private func formattedPrice(_ price: Decimal) -> String {
        price.asCurrency
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
