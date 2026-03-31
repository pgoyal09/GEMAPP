import SwiftUI
import SwiftData

struct LotSelectSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var fetchedLots: [Gemstone] = []
    @State private var selectedLotID: PersistentIdentifier?
    @State private var caratsText = ""
    @State private var searchText = ""
    @State private var validationMessage: String?

    var onSelect: (Gemstone, Double) -> Void

    private var lots: [Gemstone] {
        fetchedLots.filter { $0.effectiveRemainingCarats > 0 }
            .filter { lot in
                let q = searchText.lowercased()
                guard !q.isEmpty else { return true }
                return lot.sku.lowercased().contains(q) ||
                    lot.stoneType.rawValue.lowercased().contains(q) ||
                    lot.color.lowercased().contains(q)
            }
    }

    private var selectedLot: Gemstone? {
        lots.first { $0.persistentModelID == selectedLotID }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search
            HStack {
                GlassSearchField(text: $searchText, placeholder: "Search lots…")
            }
            .padding(AppSpacing.section)

            // Lot list
            ScrollView {
                LazyVStack(spacing: 0) {
                    HStack(spacing: 0) {
                        TableHeader(title: "SKU", width: TableColumn.sku)
                        TableHeader(title: "Type", width: TableColumn.type)
                        TableHeader(title: "Remaining", width: TableColumn.carat)
                        TableHeader(title: "Sell/ct", width: TableColumn.price)
                        Spacer()
                    }
                    .padding(.horizontal, AppSpacing.section)

                    ForEach(lots) { lot in
                        let isSelected = selectedLotID == lot.persistentModelID
                        HoverRow(isSelected: isSelected, onTap: { selectedLotID = lot.persistentModelID }) {
                            Text(lot.sku).font(AppTypography.mono).frame(width: TableColumn.sku, alignment: .leading)
                            StoneTypeBadge(type: lot.stoneType.rawValue).frame(width: TableColumn.type, alignment: .leading)
                            Text(String(format: "%.2f ct", lot.effectiveRemainingCarats)).font(AppTypography.mono)
                                .frame(width: TableColumn.carat, alignment: .trailing)
                            Text(lot.sellPrice.asCurrency).font(AppTypography.mono)
                                .frame(width: TableColumn.price, alignment: .trailing)
                            Spacer()
                        }
                    }
                }
            }

            // Bottom panel
            if let lot = selectedLot {
                VStack(spacing: 12) {
                    Divider().background(AppColors.cardElevated)
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Selected: \(lot.sku)").font(AppTypography.body.weight(.medium)).foregroundStyle(AppColors.ink)
                            Text("Available: \(String(format: "%.2f", lot.effectiveRemainingCarats)) ct")
                                .font(AppTypography.caption).foregroundStyle(AppColors.inkSubtle)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Carats to allocate").font(AppTypography.caption).foregroundStyle(AppColors.inkSubtle)
                            TextField("0.00", text: $caratsText).glassField().frame(width: 100)
                        }
                        if let carats = Double(caratsText), carats > 0 {
                            let amount = lot.sellPrice * Decimal(carats)
                            Text("Total: \(amount.asCurrency)")
                                .font(AppTypography.body.weight(.semibold))
                                .foregroundStyle(AppColors.primary)
                        }
                        Spacer()
                    }
                    if let msg = validationMessage {
                        Text(msg).font(AppTypography.caption).foregroundStyle(AppColors.danger)
                    }
                }
                .padding(.horizontal, AppSpacing.section)
            }

            // Footer
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(.outline)
                Button("Add Lot Allocation") { confirmSelection() }
                    .buttonStyle(.gradient)
                    .disabled(selectedLot == nil || (Double(caratsText) ?? 0) <= 0)
            }
            .padding(AppSpacing.section)
        }
        .frame(minWidth: 680, minHeight: 460)
        .onAppear { fetchLots() }
    }

    private func fetchLots() {
        let lotGrouping = StoneGrouping.lot
        let descriptor = FetchDescriptor<Gemstone>(
            predicate: #Predicate<Gemstone> { $0.grouping == lotGrouping },
            sortBy: [SortDescriptor(\.sku)]
        )
        fetchedLots = (try? modelContext.fetch(descriptor)) ?? []
    }

    private func confirmSelection() {
        guard let lot = selectedLot, let carats = Double(caratsText), carats > 0 else { return }
        if carats > lot.effectiveRemainingCarats {
            validationMessage = "Cannot exceed \(String(format: "%.2f", lot.effectiveRemainingCarats)) ct remaining"
            return
        }
        validationMessage = nil
        onSelect(lot, carats)
        dismiss()
    }
}
