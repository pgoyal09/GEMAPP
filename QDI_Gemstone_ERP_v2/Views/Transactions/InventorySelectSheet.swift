import SwiftUI
import SwiftData

struct InventorySelectSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private static let tableLayout = TableColumnLayout(columns: [
        ColumnDef("sku", weight: 2.0, minWidth: 80),
        ColumnDef("type", weight: 1.5, minWidth: 60),
        ColumnDef("carats", weight: 1.2, minWidth: 55),
        ColumnDef("color", weight: 1.5, minWidth: 60),
        ColumnDef("shape", weight: 1.5, minWidth: 60),
        ColumnDef("price", weight: 1.5, minWidth: 70),
    ], spacing: AppSpacing.tableColumnGap)

    @State private var fetchedStones: [Gemstone] = []
    @State private var selectedIDs: Set<PersistentIdentifier> = []
    @State private var searchText = ""
    @State private var typeFilter: StoneType? = nil
    @State private var availableOnly = true

    var onSelect: ([Gemstone]) -> Void

    private var filteredStones: [Gemstone] {
        fetchedStones.filter { stone in
            if let type = typeFilter, stone.stoneType != type { return false }
            let q = searchText.lowercased()
            if !q.isEmpty {
                return stone.sku.lowercased().contains(q) ||
                    stone.stoneType.rawValue.lowercased().contains(q) ||
                    stone.color.lowercased().contains(q) ||
                    stone.clarity.lowercased().contains(q) ||
                    stone.shape.lowercased().contains(q)
            }
            return true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: AppSpacing.comfortable) {
                GlassSearchField(text: $searchText, placeholder: "Search SKU, type, color…")
                Picker("Type", selection: $typeFilter) {
                    Text("All Types").tag(StoneType?.none)
                    ForEach(StoneType.allCases, id: \.self) { Text($0.rawValue).tag(StoneType?.some($0)) }
                }
                .frame(width: 140)
                Toggle("Available only", isOn: $availableOnly)
                    .toggleStyle(.checkbox)
            }
            .padding(AppSpacing.section)

            // Table
            GeometryReader { geo in
                let widths = Self.tableLayout.widths(for: geo.size.width - 2 * AppSpacing.standard)
                ScrollView {
                    LazyVStack(spacing: 0) {
                        HStack(spacing: AppSpacing.tableColumnGap) {
                            TableHeader(title: "SKU", width: widths[0])
                            TableHeader(title: "Type", width: widths[1])
                            TableHeader(title: "Carats", width: widths[2])
                            TableHeader(title: "Color", width: widths[3])
                            TableHeader(title: "Shape", width: widths[4])
                            TableHeader(title: "Price", width: widths[5])
                        }
                        .padding(.horizontal, AppSpacing.standard)

                        ForEach(filteredStones) { stone in
                            let isSelected = selectedIDs.contains(stone.persistentModelID)
                            HoverRow(isSelected: isSelected, onTap: {
                                if isSelected { selectedIDs.remove(stone.persistentModelID) }
                                else { selectedIDs.insert(stone.persistentModelID) }
                            }) {
                                Text(stone.sku).font(AppTypography.mono).frame(width: widths[0], alignment: .leading)
                                StoneTypeBadge(type: stone.stoneType.rawValue).frame(width: widths[1], alignment: .leading)
                                Text(String(format: "%.2f", stone.caratWeight)).font(AppTypography.mono).frame(width: widths[2], alignment: .trailing)
                                Text(stone.color).font(AppTypography.body).frame(width: widths[3], alignment: .leading)
                                Text(stone.shape).font(AppTypography.body).frame(width: widths[4], alignment: .leading)
                                Text(stone.sellPrice.asCurrency(stone.currencyType)).font(AppTypography.mono).frame(width: widths[5], alignment: .trailing)
                            }
                        }
                    }
                }
            }

            // Footer
            HStack {
                Text("\(selectedIDs.count) selected")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.inkSubtle)
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(.outline)
                Button("Add \(selectedIDs.count) Stone\(selectedIDs.count == 1 ? "" : "s")") {
                    let stones = fetchedStones.filter { selectedIDs.contains($0.persistentModelID) }
                    onSelect(stones)
                    dismiss()
                }
                .buttonStyle(.gradient)
                .disabled(selectedIDs.isEmpty)
            }
            .padding(AppSpacing.section)
        }
        .frame(minWidth: 720, minHeight: 420)
        .onAppear { fetchStones() }
        .onChange(of: availableOnly) { _, _ in fetchStones() }
    }

    private func fetchStones() {
        // SwiftData #Predicate does not support custom enum types as captured constants.
        // Fetch all stones and filter in memory instead.
        let descriptor = FetchDescriptor<Gemstone>(
            sortBy: [SortDescriptor(\.sku)]
        )
        let all = (try? modelContext.fetch(descriptor)) ?? []
        if availableOnly {
            fetchedStones = all.filter { $0.grouping != .lot && $0.status == .available }
        } else {
            fetchedStones = all.filter { $0.grouping != .lot }
        }
    }
}
