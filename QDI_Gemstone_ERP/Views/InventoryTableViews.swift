import SwiftUI
import SwiftData

extension InventoryListView {
    /// Pre-fetch all invoice line-items with gemstones once, then build lookup maps.
    /// This replaces the per-row N+1 queries with a single batch fetch.
    private func soldStoneLineItems() -> [String: LineItem] {
        let descriptor = FetchDescriptor<LineItem>(
            predicate: #Predicate<LineItem> { item in
                item.invoice != nil
            }
        )
        guard let items = try? modelContext.fetch(descriptor) else { return [:] }
        var map: [String: LineItem] = [:]
        for item in items {
            if let sku = item.gemstone?.sku {
                map[sku] = item
            }
        }
        return map
    }

    func soldToCustomer(for stone: Gemstone) -> String {
        let map = soldStoneLineItems()
        guard let customer = map[stone.sku]?.invoice?.customer else { return "—" }
        return customer.displayName
    }

    func invoiceForSoldStone(_ stone: Gemstone) -> Invoice? {
        let map = soldStoneLineItems()
        return map[stone.sku]?.invoice
    }

    var soldInventoryTable: some View {
        AppSurfaceCard(padding: AppSpacing.s) {
            VStack(spacing: 0) {
                AppTableHeader(columns: [
                    AppTableHeader.Column("SKU", width: 100),
                    AppTableHeader.Column("TYPE", width: 90),
                    AppTableHeader.Column("STATUS", width: 80),
                    AppTableHeader.Column("SOLD TO", width: 120),
                    AppTableHeader.Column("CARAT", width: 80, alignment: .trailing),
                    AppTableHeader.Column("COLOR", width: 80),
                    AppTableHeader.Column("SELL", width: 110, alignment: .trailing)
                ])
                Divider().background(Color.white.opacity(0.06))
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredGemstones) { stone in
                            AppTableHoverRow(
                                isSelected: selectedStoneID == stone.id,
                                onTap: { selectedStoneID = stone.id }
                            ) {
                                HStack(spacing: 0) {
                                    Text(stone.sku)
                                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                                        .foregroundStyle(AppColors.ink)
                                        .lineLimit(1)
                                        .frame(width: 100, alignment: .leading)
                                        .padding(.horizontal, 4)
                                    StoneTypeBadge(type: stone.stoneType.rawValue)
                                        .frame(width: 90, alignment: .leading)
                                        .padding(.horizontal, 4)
                                    AppStatusBadge(title: stone.effectiveStatus.rawValue, tone: statusBadgeTone(for: stone))
                                        .frame(width: 80, alignment: .leading)
                                        .padding(.horizontal, 4)
                                    Text(soldToCustomer(for: stone))
                                        .foregroundStyle(AppColors.ink)
                                        .lineLimit(1)
                                        .frame(width: 120, alignment: .leading)
                                        .padding(.horizontal, 4)
                                    Text(String(format: "%.2f", stone.caratWeight))
                                        .foregroundStyle(AppColors.inkMuted)
                                        .frame(width: 80, alignment: .trailing)
                                        .padding(.horizontal, 4)
                                    Text(stone.color)
                                        .foregroundStyle(AppColors.inkMuted)
                                        .lineLimit(1)
                                        .frame(width: 80, alignment: .leading)
                                        .padding(.horizontal, 4)
                                    Text(stone.sellPrice.asCurrency)
                                        .foregroundStyle(AppColors.ink)
                                        .frame(width: 110, alignment: .trailing)
                                        .padding(.horizontal, 4)
                                }
                                .padding(.horizontal, AppSpacing.l)
                            }
                            .onTapGesture(count: 2) {
                                selectedStoneID = stone.id
                                showEditSheet = true
                            }
                            .contextMenu {
                                Button("Edit...") { showEditSheet = true }
                                Button("View Invoice") {
                                    guard let inv = invoiceForSoldStone(stone) else { return }
                                    openWindow(id: "invoice", value: inv.id)
                                }
                                Divider()
                                PrintTagButton(gemstone: stone, style: .contextMenu)
                            }
                            Divider().background(Color.white.opacity(0.03))
                        }
                    }
                }
            }
        }
    }

    var currentInventoryTableWithColor: some View {
        AppSurfaceCard(padding: AppSpacing.s) {
            VStack(spacing: 0) {
                AppTableHeader(columns: [
                    AppTableHeader.Column("SKU", width: 100),
                    AppTableHeader.Column("TYPE", width: 90),
                    AppTableHeader.Column("STATUS", width: 80),
                    AppTableHeader.Column("CARAT", width: 80, alignment: .trailing),
                    AppTableHeader.Column("COLOR", width: 80),
                    AppTableHeader.Column("SELL", width: 110, alignment: .trailing)
                ])
                Divider().background(Color.white.opacity(0.06))
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredGemstones) { stone in
                            AppTableHoverRow(
                                isSelected: selectedStoneID == stone.id,
                                onTap: { selectedStoneID = stone.id }
                            ) {
                                HStack(spacing: 0) {
                                    Text(stone.sku)
                                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                                        .foregroundStyle(AppColors.ink)
                                        .lineLimit(1)
                                        .frame(width: 100, alignment: .leading)
                                        .padding(.horizontal, 4)
                                    StoneTypeBadge(type: stone.stoneType.rawValue)
                                        .frame(width: 90, alignment: .leading)
                                        .padding(.horizontal, 4)
                                    AppStatusBadge(title: stone.effectiveStatus.rawValue, tone: statusBadgeTone(for: stone))
                                        .frame(width: 80, alignment: .leading)
                                        .padding(.horizontal, 4)
                                    Text(String(format: "%.2f", stone.caratWeight))
                                        .foregroundStyle(AppColors.inkMuted)
                                        .frame(width: 80, alignment: .trailing)
                                        .padding(.horizontal, 4)
                                    Text(stone.color)
                                        .foregroundStyle(AppColors.inkMuted)
                                        .lineLimit(1)
                                        .frame(width: 80, alignment: .leading)
                                        .padding(.horizontal, 4)
                                    Text(stone.sellPrice.asCurrency)
                                        .foregroundStyle(AppColors.ink)
                                        .frame(width: 110, alignment: .trailing)
                                        .padding(.horizontal, 4)
                                }
                                .padding(.horizontal, AppSpacing.l)
                            }
                            .onTapGesture(count: 2) {
                                selectedStoneID = stone.id
                                showEditSheet = true
                            }
                            .contextMenu {
                                Button("Edit...") { showEditSheet = true }
                                Divider()
                                PrintTagButton(gemstone: stone, style: .contextMenu)
                            }
                            Divider().background(Color.white.opacity(0.03))
                        }
                    }
                }
            }
        }
    }

    var currentInventoryTable: some View {
        AppSurfaceCard(padding: AppSpacing.s) {
            VStack(spacing: 0) {
                AppTableHeader(columns: [
                    AppTableHeader.Column("SKU", width: 100),
                    AppTableHeader.Column("TYPE", width: 90),
                    AppTableHeader.Column("STATUS", width: 80),
                    AppTableHeader.Column("CARAT", width: 80, alignment: .trailing),
                    AppTableHeader.Column("SELL", width: 110, alignment: .trailing)
                ])
                Divider().background(Color.white.opacity(0.06))
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredGemstones) { stone in
                            AppTableHoverRow(
                                isSelected: selectedStoneID == stone.id,
                                onTap: { selectedStoneID = stone.id }
                            ) {
                                HStack(spacing: 0) {
                                    Text(stone.sku)
                                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                                        .foregroundStyle(AppColors.ink)
                                        .lineLimit(1)
                                        .frame(width: 100, alignment: .leading)
                                        .padding(.horizontal, 4)
                                    StoneTypeBadge(type: stone.stoneType.rawValue)
                                        .frame(width: 90, alignment: .leading)
                                        .padding(.horizontal, 4)
                                    AppStatusBadge(title: stone.effectiveStatus.rawValue, tone: statusBadgeTone(for: stone))
                                        .frame(width: 80, alignment: .leading)
                                        .padding(.horizontal, 4)
                                    Text(String(format: "%.2f", stone.caratWeight))
                                        .foregroundStyle(AppColors.inkMuted)
                                        .frame(width: 80, alignment: .trailing)
                                        .padding(.horizontal, 4)
                                    Text(stone.sellPrice.asCurrency)
                                        .foregroundStyle(AppColors.ink)
                                        .frame(width: 110, alignment: .trailing)
                                        .padding(.horizontal, 4)
                                }
                                .padding(.horizontal, AppSpacing.l)
                            }
                            .onTapGesture(count: 2) {
                                selectedStoneID = stone.id
                                showEditSheet = true
                            }
                            .contextMenu {
                                Button("Edit...") { showEditSheet = true }
                                Divider()
                                PrintTagButton(gemstone: stone, style: .contextMenu)
                            }
                            Divider().background(Color.white.opacity(0.03))
                        }
                    }
                }
            }
        }
    }

    func statusBadgeTone(for stone: Gemstone) -> AppStatusBadge.Tone {
        switch stone.effectiveStatus {
        case .available: return .success
        case .onMemo:    return .warning
        case .sold:      return .neutral
        default:         return .neutral
        }
    }
}
