import SwiftUI
import SwiftData

struct LotSelectSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private static let tableLayout = TableColumnLayout(columns: [
        ColumnDef("sku", weight: 2.0, minWidth: 80),
        ColumnDef("type", weight: 1.5, minWidth: 60),
        ColumnDef("remaining", weight: 1.5, minWidth: 60),
        ColumnDef("sellPerCt", weight: 1.5, minWidth: 70),
    ], spacing: 4)

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
            GeometryReader { geo in
                let widths = Self.tableLayout.widths(for: geo.size.width - 2 * AppSpacing.standard)
                ScrollView {
                    LazyVStack(spacing: 0) {
                        HStack(spacing: 4) {
                            TableHeader(title: "SKU", width: widths[0])
                            TableHeader(title: "Type", width: widths[1])
                            TableHeader(title: "Remaining", width: widths[2])
                            TableHeader(title: "Sell/ct", width: widths[3])
                        }
                        .padding(.horizontal, AppSpacing.standard)

                        ForEach(lots) { lot in
                            let isSelected = selectedLotID == lot.persistentModelID
                            HoverRow(isSelected: isSelected, onTap: { selectedLotID = lot.persistentModelID }) {
                                Text(lot.sku).font(AppTypography.mono).frame(width: widths[0], alignment: .leading)
                                StoneTypeBadge(type: lot.stoneType.rawValue).frame(width: widths[1], alignment: .leading)
                                Text(String(format: "%.2f ct", lot.effectiveRemainingCarats)).font(AppTypography.mono)
                                    .frame(width: widths[2], alignment: .trailing)
                                Text(lot.sellPrice.asCurrency).font(AppTypography.mono)
                                    .frame(width: widths[3], alignment: .trailing)
                            }
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
        // SwiftData #Predicate does not support custom enum types as captured constants.
        // Fetch all stones and filter in memory instead.
        let descriptor = FetchDescriptor<Gemstone>(
            sortBy: [SortDescriptor(\.sku)]
        )
        fetchedLots = ((try? modelContext.fetch(descriptor)) ?? [])
            .filter { $0.grouping == .lot }
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
