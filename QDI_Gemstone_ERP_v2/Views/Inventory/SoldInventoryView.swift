import SwiftUI
import SwiftData

struct SoldInventoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Query private var allStones: [Gemstone]

    init() {
        // SwiftData #Predicate does not support custom enum types as captured constants.
        // Fetch all and filter in computed property instead.
        _allStones = Query(sort: \Gemstone.createdAt, order: .reverse)
    }

    @State private var searchText = ""
    @State private var selectedStoneID: PersistentIdentifier?
    @State private var showEditSheet = false
    @State private var editingStone: Gemstone?

    // MARK: - Sort State

    @State private var sortKey: String = "sku"
    @State private var sortAscending: Bool = true

    // MARK: - Filter State

    @State private var typeToggle: SoldTypeToggle = .all

    enum SoldTypeToggle: String, CaseIterable {
        case all = "All"
        case diamonds = "Diamonds"
        case gemstones = "Gemstones"
        case lots = "Lots"
    }

    // MARK: - Computed

    private var filteredStones: [Gemstone] {
        var result = allStones.filter { $0.status == .sold }

        switch typeToggle {
        case .all: break
        case .diamonds: result = result.filter { $0.stoneType == .diamond && $0.grouping != .lot }
        case .gemstones: result = result.filter { $0.stoneType != .diamond && $0.grouping != .lot }
        case .lots: result = result.filter { $0.grouping == .lot }
        }

        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            result = result.filter {
                $0.sku.lowercased().contains(q) ||
                $0.stoneType.rawValue.lowercased().contains(q) ||
                $0.color.lowercased().contains(q) ||
                $0.currentLocation.lowercased().contains(q)
            }
        }
        return sortedStones(result)
    }

    private func sortedStones(_ stones: [Gemstone]) -> [Gemstone] {
        stones.sorted { a, b in
            let asc: Bool
            switch sortKey {
            case "type": asc = a.stoneType.rawValue.localizedCompare(b.stoneType.rawValue) == .orderedAscending
            case "carat": asc = a.caratWeight < b.caratWeight
            case "price": asc = a.sellPrice < b.sellPrice
            case "cost": asc = a.costPrice < b.costPrice
            case "margin":
                let mA = a.costPrice > 0 ? ((a.sellPrice - a.costPrice) / a.costPrice) : 0
                let mB = b.costPrice > 0 ? ((b.sellPrice - b.costPrice) / b.costPrice) : 0
                asc = mA < mB
            case "date": asc = a.createdAt < b.createdAt
            default: asc = a.sku.localizedCompare(b.sku) == .orderedAscending
            }
            return sortAscending ? asc : !asc
        }
    }

    private func toggleSort(_ key: String) {
        if sortKey == key { sortAscending.toggle() }
        else { sortKey = key; sortAscending = true }
    }

    private var selectedStone: Gemstone? {
        guard let id = selectedStoneID else { return nil }
        return filteredStones.first { $0.persistentModelID == id }
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 4) {
            VStack(spacing: 0) {
                topBar
                tableContent
            }
            .frame(minWidth: 500, maxWidth: .infinity, maxHeight: .infinity)

            if let stone = selectedStone {
                Divider().background(AppColors.cardStroke)
                GemstoneDetailPanel(gemstone: stone, onEdit: {
                    editingStone = stone
                    showEditSheet = true
                })
                .frame(minWidth: 260, idealWidth: 296, maxWidth: 350)
            }
        }
        .animation(reduceMotion ? nil : AppAnimation.sheetSpring, value: selectedStone?.persistentModelID)
        .sheet(isPresented: $showEditSheet) {
            if let stone = editingStone {
                StoneFormView(mode: .edit(stone))
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: AppSpacing.comfortable) {
            GlassSearchField(text: $searchText, placeholder: "Search sold stones...")
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
        }
        .padding(.horizontal, AppSpacing.hero)
        .padding(.vertical, AppSpacing.section)
    }

    // MARK: - Table

    private var tableContent: some View {
        ScrollView([.horizontal, .vertical]) {
            LazyVStack(spacing: 0) {
                tableHeader
                Divider().background(AppColors.cardStroke)
                if filteredStones.isEmpty {
                    EmptyStateView(icon: "tag.slash", title: "No sold stones", subtitle: "Sold inventory will appear here")
                } else {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(filteredStones.enumerated()), id: \.element.persistentModelID) { index, stone in
                            stoneRow(stone)
                                .staggeredRow(index: index, reduceMotion: reduceMotion)
                        }
                    }
                    .padding(.vertical, AppSpacing.standard)
                    summaryFooter
                }
            }
            .frame(minWidth: 1000, maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .glassTable()
        .padding(.horizontal, AppSpacing.hero)
        .padding(.bottom, AppSpacing.hero)
    }

    private var tableHeader: some View {
        HStack(spacing: 4) {
            sortableHeader("SKU", key: "sku", width: TableColumn.sku, alignment: .leading)
            sortableHeader("Type", key: "type", width: TableColumn.type, alignment: .leading)
            TableHeader(title: "Shape", width: TableColumn.shape, alignment: .leading)
            sortableHeader("Carat", key: "carat", width: TableColumn.carat, alignment: .trailing)
            TableHeader(title: "Color", width: TableColumn.color, alignment: .leading)
            sortableHeader("Ask $/ct", key: "price", width: TableColumn.price, alignment: .trailing)
            sortableHeader("Cost $/ct", key: "cost", width: TableColumn.price, alignment: .trailing)
            sortableHeader("Margin%", key: "margin", width: TableColumn.margin, alignment: .trailing)
            sortableHeader("Sold Date", key: "date", width: TableColumn.date, alignment: .leading)
            Spacer()
        }
        .padding(.horizontal, AppSpacing.section)
        .padding(.vertical, AppSpacing.comfortable)
    }

    private func sortableHeader(_ title: String, key: String, width: CGFloat, alignment: Alignment) -> TableHeader {
        TableHeader(title: title, width: width, alignment: alignment, isSorted: sortKey == key, ascending: sortAscending, onTap: { toggleSort(key) })
    }

    private func stoneRow(_ stone: Gemstone) -> some View {
        HoverRow(isSelected: selectedStoneID == stone.persistentModelID, onTap: {
            selectedStoneID = selectedStoneID == stone.persistentModelID ? nil : stone.persistentModelID
        }) {
            Text(stone.sku).font(AppTypography.mono).foregroundStyle(AppColors.ink).lineLimit(1).frame(width: TableColumn.sku, alignment: .leading)
            StoneTypeBadge(type: stone.stoneType.rawValue).frame(width: TableColumn.type, alignment: .leading)
            Text(stone.shape).font(AppTypography.body).foregroundStyle(AppColors.ink).lineLimit(1).frame(width: TableColumn.shape, alignment: .leading)
            Text(String(format: "%.2f", stone.caratWeight)).font(AppTypography.mono).foregroundStyle(AppColors.ink).frame(width: TableColumn.carat, alignment: .trailing)
            Text(stone.color).font(AppTypography.body).foregroundStyle(AppColors.ink).lineLimit(1).frame(width: TableColumn.color, alignment: .leading)
            Text(stone.sellPrice.asCurrency).font(AppTypography.mono).foregroundStyle(AppColors.ink).frame(width: TableColumn.price, alignment: .trailing)
            Text(stone.costPrice.asCurrency).font(AppTypography.mono).foregroundStyle(AppColors.inkMuted).frame(width: TableColumn.price, alignment: .trailing)
            Text(marginText(stone)).font(AppTypography.mono).foregroundStyle(marginColor(stone)).frame(width: TableColumn.margin, alignment: .trailing)
            Text(stone.createdAt.formatted(.dateTime.month(.abbreviated).day().year())).font(AppTypography.caption).foregroundStyle(AppColors.inkMuted).frame(width: TableColumn.date, alignment: .leading)
            Spacer()
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
        .padding(.horizontal, AppSpacing.section).padding(.vertical, AppSpacing.comfortable)
        .background(AppColors.softHighlight)
    }

    // MARK: - Helpers

    private func marginText(_ stone: Gemstone) -> String {
        guard stone.costPrice > 0 else { return "—" }
        let margin = ((stone.sellPrice - stone.costPrice) / stone.costPrice) * 100
        return "\(NSDecimalNumber(decimal: margin).intValue)%"
    }

    private func marginColor(_ stone: Gemstone) -> Color {
        guard stone.costPrice > 0 else { return AppColors.inkMuted }
        return stone.sellPrice >= stone.costPrice ? AppColors.success : AppColors.danger
    }
}
