import SwiftUI
import SwiftData

struct LotInventoryView: View {
    @Binding var selectedNavigationItem: NavigationItem
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Gemstone.sku) private var allGemstones: [Gemstone]

    @State private var searchText = ""
    @State private var sortOrder: LotSortOrder = .sku
    @State private var sortAscending = true
    @State private var selectedLotID: PersistentIdentifier?
    @State private var showHistorySheet = false
    @State private var showAddQtySheet = false
    @State private var targetLot: Gemstone?

    enum LotSortOrder: String, CaseIterable {
        case sku = "SKU"
        case stoneType = "Type"
        case remaining = "Remaining"
        case avgCost = "Avg Cost"
        case value = "Value"
    }

    private var lotStones: [Gemstone] {
        allGemstones.filter { $0.grouping == "L" }
    }

    private var filteredLots: [Gemstone] {
        var result = lotStones
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            result = result.filter {
                $0.sku.lowercased().contains(q) ||
                $0.stoneType.rawValue.lowercased().contains(q) ||
                $0.color.lowercased().contains(q) ||
                $0.clarity.lowercased().contains(q) ||
                ($0.shape ?? "").lowercased().contains(q) ||
                ($0.quality ?? "").lowercased().contains(q)
            }
        }
        result.sort { a, b in
            let cmp: Bool
            switch sortOrder {
            case .sku: cmp = a.sku < b.sku
            case .stoneType: cmp = a.stoneType.rawValue < b.stoneType.rawValue
            case .remaining: cmp = a.effectiveRemainingCarats < b.effectiveRemainingCarats
            case .avgCost: cmp = a.effectiveAverageCost < b.effectiveAverageCost
            case .value:
                let va = a.effectiveRemainingCarats * Double(truncating: a.sellPrice as NSDecimalNumber)
                let vb = b.effectiveRemainingCarats * Double(truncating: b.sellPrice as NSDecimalNumber)
                cmp = va < vb
            }
            return sortAscending ? cmp : !cmp
        }
        return result
    }

    private var selectedLot: Gemstone? {
        guard let id = selectedLotID else { return nil }
        return lotStones.first { $0.id == id }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerRow
            searchRow
            columnHeaders
            Divider().overlay(AppColors.cardStroke)
            if filteredLots.isEmpty {
                ContentUnavailableView(
                    "No Lots",
                    systemImage: "cube.box",
                    description: Text(searchText.isEmpty ? "Add lot stones via Quick Intake." : "No lots match your search.")
                )
                .foregroundStyle(AppColors.inkMuted)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredLots) { lot in
                            LotRow(
                                lot: lot,
                                isSelected: selectedLotID == lot.id,
                                onTap: { selectedLotID = lot.id }
                            )
                            Divider().overlay(AppColors.cardStroke)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            summaryStrip
        }
        .background(AppColors.background)
        .sheet(isPresented: $showHistorySheet) {
            if let lot = targetLot {
                LotHistorySheet(lot: lot)
            }
        }
        .sheet(isPresented: $showAddQtySheet) {
            if let lot = targetLot {
                AddLotQuantitySheet(lot: lot)
            }
        }
        .onChange(of: showAddQtySheet) { _, isOpen in
            // refresh after adding qty
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(spacing: AppSpacing.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Lot Inventory")
                    .font(.title2.bold())
                    .foregroundStyle(AppColors.ink)
                Text("\(lotStones.count) lots total")
                    .font(.caption)
                    .foregroundStyle(AppColors.inkMuted)
            }
            Spacer()
            if let lot = selectedLot {
                PrintTagButton(gemstone: lot, style: .pill)
                PillActionButton("View History", icon: "clock") {
                    targetLot = lot
                    showHistorySheet = true
                }
                PillActionButton("Add Quantity", icon: "plus") {
                    targetLot = lot
                    showAddQtySheet = true
                }
            }
            GradientButton(title: "Add Lot", icon: "plus.circle.fill") {
                selectedNavigationItem = .quickIntake
            }
        }
        .padding(.horizontal, AppSpacing.l)
        .padding(.vertical, AppSpacing.m)
        .animation(.easeInOut(duration: 0.15), value: selectedLotID != nil)
    }

    // MARK: - Search

    private var searchRow: some View {
        HStack(spacing: AppSpacing.m) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.white.opacity(0.25))
                TextField("Search lots…", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.white.opacity(0.80))
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.white.opacity(0.40))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
            .frame(maxWidth: 320)
            Spacer()
        }
        .padding(.horizontal, AppSpacing.l)
        .padding(.bottom, AppSpacing.s)
    }

    // MARK: - Column Headers

    private var columnHeaders: some View {
        HStack(spacing: 0) {
            sortHeader("SKU", order: .sku, width: 100)
            sortHeader("Type", order: .stoneType, width: 90)
            Text("Color / Clarity").frame(width: 140, alignment: .leading).padding(.horizontal, 4)
                .font(.caption).fontWeight(.semibold).foregroundStyle(AppColors.inkSubtle)
            Text("Shape / Quality").frame(width: 120, alignment: .leading).padding(.horizontal, 4)
                .font(.caption).fontWeight(.semibold).foregroundStyle(AppColors.inkSubtle)
            sortHeader("Remaining ct", order: .remaining, width: 100)
            sortHeader("Avg Cost/ct", order: .avgCost, width: 100)
            sortHeader("Sell Value", order: .value, width: 100)
            Spacer()
        }
        .padding(.horizontal, AppSpacing.l)
        .padding(.vertical, 6)
        .background(AppColors.cardBackground)
    }

    private func sortHeader(_ title: String, order: LotSortOrder, width: CGFloat) -> some View {
        Button {
            if sortOrder == order {
                sortAscending.toggle()
            } else {
                sortOrder = order
                sortAscending = true
            }
        } label: {
            HStack(spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppColors.inkSubtle)
                if sortOrder == order {
                    Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8))
                        .foregroundStyle(AppColors.inkSubtle)
                }
            }
        }
        .buttonStyle(.plain)
        .frame(width: width, alignment: .leading)
        .padding(.horizontal, 4)
    }

    // MARK: - Summary

    private var summaryStrip: some View {
        let totalRemaining = filteredLots.reduce(0.0) { $0 + $1.effectiveRemainingCarats }
        let totalValue = filteredLots.reduce(Decimal(0)) { sum, lot in
            sum + lot.sellPrice * Decimal(lot.effectiveRemainingCarats)
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return HStack(spacing: AppSpacing.xl) {
            Label("\(filteredLots.count) lots", systemImage: "cube.box")
            Label(String(format: "%.2f ct remaining", totalRemaining), systemImage: "scalemass")
            Label(formatter.string(from: totalValue as NSDecimalNumber) ?? "$0", systemImage: "dollarsign.circle")
            Spacer()
        }
        .font(.caption)
        .foregroundStyle(AppColors.inkMuted)
        .padding(.horizontal, AppSpacing.l)
        .padding(.vertical, AppSpacing.s)
        .background(AppColors.cardBackground)
    }
}

// MARK: - Lot Row

private struct LotRow: View {
    let lot: Gemstone
    let isSelected: Bool
    let onTap: () -> Void

    @State private var isHovered = false

    private var remainingColor: Color {
        if lot.effectiveRemainingCarats <= 0 { return AppColors.danger }
        if lot.effectiveRemainingCarats < lot.caratWeight * 0.2 { return AppColors.warning }
        return AppColors.ink
    }

    var body: some View {
        HStack(spacing: 0) {
            Text(lot.sku)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(AppColors.ink)
                .frame(width: 100, alignment: .leading)
                .padding(.horizontal, 4)
            StoneTypeBadge(type: lot.stoneType.rawValue)
                .frame(width: 90, alignment: .leading)
                .padding(.horizontal, 4)
            VStack(alignment: .leading, spacing: 0) {
                Text(lot.color.isEmpty ? "—" : lot.color)
                    .foregroundStyle(AppColors.ink)
                Text(lot.clarity.isEmpty ? "—" : lot.clarity)
                    .font(.caption)
                    .foregroundStyle(AppColors.inkMuted)
            }
            .frame(width: 140, alignment: .leading)
            .padding(.horizontal, 4)
            VStack(alignment: .leading, spacing: 0) {
                Text(lot.shape ?? "—")
                    .foregroundStyle(AppColors.ink)
                if let quality = lot.quality, !quality.isEmpty {
                    Text(quality).font(.caption).foregroundStyle(AppColors.inkMuted)
                } else if let size = lot.size, !size.isEmpty {
                    Text(size).font(.caption).foregroundStyle(AppColors.inkMuted)
                }
            }
            .frame(width: 120, alignment: .leading)
            .padding(.horizontal, 4)
            Text(String(format: "%.2f ct", lot.effectiveRemainingCarats))
                .foregroundStyle(remainingColor)
                .frame(width: 100, alignment: .leading)
                .padding(.horizontal, 4)
            Text(lot.effectiveAverageCost.asCurrency)
                .foregroundStyle(AppColors.ink)
                .frame(width: 100, alignment: .leading)
                .padding(.horizontal, 4)
            Text((lot.sellPrice * Decimal(lot.effectiveRemainingCarats)).asCurrency)
                .foregroundStyle(AppColors.ink)
                .frame(width: 100, alignment: .leading)
                .padding(.horizontal, 4)
            Spacer()
        }
        .padding(.horizontal, AppSpacing.l)
        .padding(.vertical, 8)
        .background(isSelected ? AppColors.primary.opacity(0.10) : (isHovered ? Color.white.opacity(0.04) : Color.clear))
        .onTapGesture { onTap() }
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
    }

}

// MARK: - Pill Action Button

struct PillActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    init(_ title: String, icon: String, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.white.opacity(0.85))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                        )
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
