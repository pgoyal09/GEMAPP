import SwiftUI
import SwiftData

struct SoldInventoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Query private var allStones: [Gemstone]

    init() {
        _allStones = Query(sort: \Gemstone.createdAt, order: .reverse)
    }

    @State private var searchText = ""
    @State private var selectedStoneID: PersistentIdentifier?
    @State private var showEditSheet = false
    @State private var editingStone: Gemstone?
    @State private var doubleClickedStone: Gemstone?

    // MARK: - Sort State

    @State private var sortKey: String = "sku"
    @State private var sortAscending: Bool = true

    // MARK: - Filter State

    @State private var typeToggle: SoldTypeToggle = .all
    @State private var showAdvancedFilters = false
    @State private var customerFilter = ""
    @State private var dateFrom: Date? = nil
    @State private var dateTo: Date? = nil
    @State private var caratMin: Double? = nil
    @State private var caratMax: Double? = nil
    @State private var priceMin: Decimal? = nil
    @State private var priceMax: Decimal? = nil
    @State private var stoneTypeFilter: StoneType? = nil

    enum SoldTypeToggle: String, CaseIterable {
        case all = "All"
        case diamonds = "Diamonds"
        case gemstones = "Gemstones"
        case lots = "Lots"
    }

    // MARK: - Computed

    private var activeFilterCount: Int {
        var count = 0
        if !customerFilter.isEmpty { count += 1 }
        if dateFrom != nil { count += 1 }
        if dateTo != nil { count += 1 }
        if caratMin != nil || caratMax != nil { count += 1 }
        if priceMin != nil || priceMax != nil { count += 1 }
        if stoneTypeFilter != nil { count += 1 }
        return count
    }

    private var uniqueCustomers: [String] {
        let names = allStones.filter { $0.status == .sold }
            .compactMap { $0.memo?.customer?.displayName }
        return Array(Set(names)).sorted()
    }

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
                $0.currentLocation.lowercased().contains(q) ||
                customerName(for: $0).lowercased().contains(q)
            }
        }

        // Advanced filters
        if !customerFilter.isEmpty {
            result = result.filter { customerName(for: $0) == customerFilter }
        }
        if let from = dateFrom {
            result = result.filter { $0.createdAt >= from }
        }
        if let to = dateTo {
            result = result.filter { $0.createdAt <= Calendar.current.date(byAdding: .day, value: 1, to: to) ?? to }
        }
        if let min = caratMin { result = result.filter { $0.caratWeight >= min } }
        if let max = caratMax { result = result.filter { $0.caratWeight <= max } }
        if let min = priceMin { result = result.filter { $0.sellPrice >= min } }
        if let max = priceMax { result = result.filter { $0.sellPrice <= max } }
        if let type = stoneTypeFilter { result = result.filter { $0.stoneType == type } }

        return sortedStones(result)
    }

    private func sortedStones(_ stones: [Gemstone]) -> [Gemstone] {
        stones.sorted { a, b in
            let asc: Bool
            switch sortKey {
            case "type": asc = a.stoneType.rawValue.localizedCompare(b.stoneType.rawValue) == .orderedAscending
            case "carat": asc = a.caratWeight < b.caratWeight
            case "cost": asc = a.costPrice < b.costPrice
            case "sold": asc = a.sellPrice < b.sellPrice
            case "margin":
                let mA = a.costPrice > 0 ? ((a.sellPrice - a.costPrice) / a.costPrice) : 0
                let mB = b.costPrice > 0 ? ((b.sellPrice - b.costPrice) / b.costPrice) : 0
                asc = mA < mB
            case "customer": asc = customerName(for: a).localizedCompare(customerName(for: b)) == .orderedAscending
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

    private func customerName(for stone: Gemstone) -> String {
        stone.memo?.customer?.displayName ?? "—"
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

                Button {
                    withAnimation { showAdvancedFilters.toggle() }
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.title3)
                            .foregroundStyle(showAdvancedFilters ? AppColors.primary : AppColors.inkMuted)
                        if activeFilterCount > 0 {
                            Text("\(activeFilterCount)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 14, height: 14)
                                .background(Circle().fill(AppColors.primary))
                                .offset(x: 4, y: -4)
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            if showAdvancedFilters {
                SoldFilterBar(
                    customerFilter: $customerFilter,
                    dateFrom: $dateFrom,
                    dateTo: $dateTo,
                    caratMin: $caratMin,
                    caratMax: $caratMax,
                    priceMin: $priceMin,
                    priceMax: $priceMax,
                    stoneTypeFilter: $stoneTypeFilter,
                    customers: uniqueCustomers
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            if activeFilterCount > 0 {
                HStack(spacing: AppSpacing.standard) {
                    if !customerFilter.isEmpty {
                        filterChip("Customer: \(customerFilter)") { customerFilter = "" }
                    }
                    if stoneTypeFilter != nil {
                        filterChip("Type: \(stoneTypeFilter!.rawValue)") { stoneTypeFilter = nil }
                    }
                    if dateFrom != nil || dateTo != nil {
                        filterChip("Date range") { dateFrom = nil; dateTo = nil }
                    }
                    if caratMin != nil || caratMax != nil {
                        filterChip("Carats") { caratMin = nil; caratMax = nil }
                    }
                    if priceMin != nil || priceMax != nil {
                        filterChip("Price") { priceMin = nil; priceMax = nil }
                    }
                    Spacer()
                    Button("Clear all") {
                        customerFilter = ""; stoneTypeFilter = nil
                        dateFrom = nil; dateTo = nil
                        caratMin = nil; caratMax = nil
                        priceMin = nil; priceMax = nil
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
        ScrollView(.horizontal, showsIndicators: true) {
            VStack(spacing: 0) {
                tableHeader
                Divider().background(AppColors.cardStroke)
                if filteredStones.isEmpty {
                    EmptyStateView(icon: "tag.slash", title: "No sold stones", subtitle: "Sold inventory will appear here")
                        .frame(maxWidth: .infinity)
                } else {
                    ScrollView(.vertical) {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(filteredStones.enumerated()), id: \.element.persistentModelID) { index, stone in
                                stoneRow(stone)
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

    private var tableHeader: some View {
        HStack(spacing: 4) {
            sortableHeader("SKU", key: "sku", width: TableColumn.sku, alignment: .leading)
            sortableHeader("Stone Type", key: "type", width: TableColumn.type, alignment: .leading)
            sortableHeader("Carats", key: "carat", width: TableColumn.carat, alignment: .trailing)
            sortableHeader("Cost", key: "cost", width: TableColumn.price, alignment: .trailing)
            sortableHeader("Sold Price", key: "sold", width: TableColumn.price, alignment: .trailing)
            sortableHeader("Margin%", key: "margin", width: TableColumn.margin, alignment: .trailing)
            sortableHeader("Customer", key: "customer", width: TableColumn.customer, alignment: .leading)
            sortableHeader("Date", key: "date", width: TableColumn.date, alignment: .leading)
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
            Text(stone.sku)
                .font(AppTypography.mono)
                .foregroundStyle(AppColors.ink)
                .lineLimit(1)
                .frame(width: TableColumn.sku, alignment: .leading)

            StoneTypeBadge(type: stone.stoneType.rawValue)
                .frame(width: TableColumn.type, alignment: .leading)

            Text(String(format: "%.2f", stone.caratWeight))
                .font(AppTypography.mono)
                .foregroundStyle(AppColors.ink)
                .frame(width: TableColumn.carat, alignment: .trailing)

            Text(stone.costPrice.asCurrency)
                .font(AppTypography.mono)
                .foregroundStyle(AppColors.inkMuted)
                .frame(width: TableColumn.price, alignment: .trailing)

            Text(stone.sellPrice.asCurrency)
                .font(AppTypography.mono)
                .foregroundStyle(AppColors.ink)
                .frame(width: TableColumn.price, alignment: .trailing)

            Text(marginText(stone))
                .font(AppTypography.mono)
                .foregroundStyle(marginColor(stone))
                .frame(width: TableColumn.margin, alignment: .trailing)

            Text(customerName(for: stone))
                .font(AppTypography.body)
                .foregroundStyle(AppColors.ink)
                .lineLimit(1)
                .frame(width: TableColumn.customer, alignment: .leading)

            Text(stone.createdAt.formatted(.dateTime.month(.abbreviated).day().year()))
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.inkMuted)
                .frame(width: TableColumn.date, alignment: .leading)

            Spacer()
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
                VStack(alignment: .leading, spacing: 4) {
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
                                DetailRow(label: "Cost $/ct", value: stone.costPrice.asCurrency)
                                DetailRow(label: "Sell $/ct", value: stone.sellPrice.asCurrency)
                                DetailRow(label: "Total Cost", value: totalCost.asCurrency)
                                DetailRow(label: "Total Sold", value: totalSold.asCurrency)

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
                            HStack(spacing: 4) {
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
                                    HStack(spacing: 4) {
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
        HStack(spacing: 4) {
            Text(label)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.ink)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.inkSubtle)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(AppColors.cardElevated))
    }
}
