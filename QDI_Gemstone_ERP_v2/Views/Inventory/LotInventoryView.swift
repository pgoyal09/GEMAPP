import SwiftUI
import SwiftData

struct LotInventoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Gemstone.sku) private var allStones: [Gemstone]

    @State var viewModel = LotInventoryViewModel()
    @State private var showHistorySheet = false
    @State private var historyLot: Gemstone?

    // MARK: - Computed

    private var lots: [Gemstone] {
        allStones.filter { $0.grouping == .lot }
    }

    private var filteredLots: [Gemstone] {
        viewModel.filtered(from: lots)
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
            HStack(spacing: 0) {
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
        .animation(.easeInOut(duration: 0.2), value: selectedLot?.persistentModelID)
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
        HStack(spacing: AppSpacing.s) {
            GlassSearchField(text: $viewModel.searchText, placeholder: "Search lots...")
                .frame(maxWidth: 320)

            Spacer()
        }
        .padding(.horizontal, AppSpacing.l)
        .padding(.vertical, AppSpacing.m)
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
                        ForEach(filteredLots, id: \.persistentModelID) { lot in
                            lotRow(lot)
                        }
                    }
                    .padding(.vertical, AppSpacing.xs)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .glassTable()
        .padding(.horizontal, AppSpacing.l)
        .padding(.bottom, AppSpacing.s)
    }

    private var tableHeader: some View {
        HStack(spacing: 0) {
            TableHeader(title: "SKU", width: TableColumn.sku, alignment: .leading)
            TableHeader(title: "Type", width: TableColumn.type, alignment: .leading)
            TableHeader(title: "Remaining ct", width: TableColumn.carat + 20, alignment: .trailing)
            TableHeader(title: "Avg Cost/ct", width: TableColumn.price, alignment: .trailing)
            TableHeader(title: "Sell/ct", width: TableColumn.price, alignment: .trailing)
            TableHeader(title: "Total Value", width: TableColumn.price, alignment: .trailing)
            Spacer()
        }
        .padding(.horizontal, AppSpacing.m)
        .padding(.vertical, AppSpacing.s)
    }

    private func lotRow(_ lot: Gemstone) -> some View {
        HoverRow(isSelected: viewModel.selectedLotID == lot.persistentModelID, onTap: {
            withAnimation(.easeInOut(duration: 0.15)) {
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
                .frame(width: TableColumn.sku, alignment: .leading)

            StoneTypeBadge(type: lot.stoneType.rawValue)
                .frame(width: TableColumn.type, alignment: .leading)

            Text(String(format: "%.2f", lot.effectiveRemainingCarats))
                .font(AppTypography.mono)
                .foregroundStyle(AppColors.ink)
                .frame(width: TableColumn.carat + 20, alignment: .trailing)

            Text(formattedPrice(lot.effectiveAverageCost))
                .font(AppTypography.mono)
                .foregroundStyle(AppColors.inkMuted)
                .frame(width: TableColumn.price, alignment: .trailing)

            Text(formattedPrice(lot.sellPrice))
                .font(AppTypography.mono)
                .foregroundStyle(AppColors.ink)
                .frame(width: TableColumn.price, alignment: .trailing)

            Text(formattedPrice(lot.sellPrice * Decimal(lot.effectiveRemainingCarats)))
                .font(AppTypography.mono)
                .foregroundStyle(AppColors.success)
                .frame(width: TableColumn.price, alignment: .trailing)

            Spacer()
        }
    }

    // MARK: - Detail Panel

    private func lotDetailPanel(_ lot: Gemstone) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.l) {
                GlassCard(padding: AppSpacing.m) {
                    VStack(alignment: .leading, spacing: AppSpacing.s) {
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

                GlassCard(padding: AppSpacing.m) {
                    VStack(alignment: .leading, spacing: AppSpacing.s) {
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

                GlassCard(padding: AppSpacing.m) {
                    VStack(alignment: .leading, spacing: AppSpacing.s) {
                        SectionHeader(title: "Pricing")
                        DetailRow(label: "Avg Cost/ct", value: formattedPrice(lot.effectiveAverageCost))
                        DetailRow(label: "Total Cost", value: formattedPrice(lot.effectiveAverageCost * Decimal(lot.effectiveRemainingCarats)))
                        DetailRow(label: "Sell/ct", value: formattedPrice(lot.sellPrice))
                        DetailRow(label: "Total Sell", value: formattedPrice(lot.sellPrice * Decimal(lot.effectiveRemainingCarats)))
                    }
                }

                HStack(spacing: AppSpacing.s) {
                    GradientButton(title: "Add Quantity", icon: "plus.circle.fill") {
                        viewModel.showAddQuantitySheet = true
                    }

                    Button {
                        historyLot = lot
                        showHistorySheet = true
                    } label: {
                        Label("History", systemImage: "clock")
                    }
                    .buttonStyle(.outline)
                }
            }
            .padding(AppSpacing.l)
        }
        .background(AppColors.panelBackground)
    }

    // MARK: - Summary Strip

    private var summaryStrip: some View {
        HStack(spacing: AppSpacing.xl) {
            summaryItem(label: "Total Lots", value: "\(filteredLots.count)")
            summaryItem(label: "Remaining Carats", value: String(format: "%.2f ct", totalRemainingCarats))
            summaryItem(label: "Total Sell Value", value: formattedPrice(totalSellValue))
            Spacer()
        }
        .padding(.horizontal, AppSpacing.l)
        .padding(.vertical, AppSpacing.s)
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
        VStack(alignment: .leading, spacing: AppSpacing.l) {
            Text("Add Quantity to \(lot.sku)")
                .font(AppTypography.heading)
                .foregroundStyle(AppColors.ink)

            VStack(alignment: .leading, spacing: AppSpacing.s) {
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

                GradientButton(title: "Add") {
                    do {
                        try viewModel.addQuantity(to: lot, modelContext: modelContext)
                    } catch {
                        print("Failed to add quantity: \(error.localizedDescription)")
                    }
                }
            }
        }
        .padding(AppSpacing.xl)
        .frame(width: 400)
        .appBackground()
    }

    // MARK: - History Sheet

    private func lotHistorySheet(_ lot: Gemstone) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.l) {
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
                    LazyVStack(spacing: AppSpacing.s) {
                        ForEach(transactions, id: \.persistentModelID) { tx in
                            GlassCard(padding: AppSpacing.m) {
                                HStack(spacing: AppSpacing.s) {
                                    Image(systemName: tx.type.displayIcon)
                                        .font(.system(size: 16))
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
        .padding(AppSpacing.xl)
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
