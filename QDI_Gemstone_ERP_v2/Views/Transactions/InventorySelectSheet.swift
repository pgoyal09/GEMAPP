import SwiftUI
import SwiftData

struct InventorySelectSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

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
            HStack(spacing: 12) {
                GlassSearchField(text: $searchText, placeholder: "Search SKU, type, color…")
                Picker("Type", selection: $typeFilter) {
                    Text("All Types").tag(StoneType?.none)
                    ForEach(StoneType.allCases, id: \.self) { Text($0.rawValue).tag(StoneType?.some($0)) }
                }
                .frame(width: 140)
                Toggle("Available only", isOn: $availableOnly)
                    .toggleStyle(.checkbox)
            }
            .padding(AppSpacing.m)

            // Table
            ScrollView {
                LazyVStack(spacing: 0) {
                    HStack(spacing: 0) {
                        TableHeader(title: "SKU", width: TableColumn.sku)
                        TableHeader(title: "Type", width: TableColumn.type)
                        TableHeader(title: "Carats", width: TableColumn.carat)
                        TableHeader(title: "Color", width: TableColumn.color)
                        TableHeader(title: "Shape", width: TableColumn.shape)
                        TableHeader(title: "Price", width: TableColumn.price)
                        Spacer()
                    }
                    .padding(.horizontal, AppSpacing.m)

                    ForEach(filteredStones) { stone in
                        let isSelected = selectedIDs.contains(stone.persistentModelID)
                        HoverRow(isSelected: isSelected, onTap: {
                            if isSelected { selectedIDs.remove(stone.persistentModelID) }
                            else { selectedIDs.insert(stone.persistentModelID) }
                        }) {
                            Text(stone.sku).font(AppTypography.mono).frame(width: TableColumn.sku, alignment: .leading)
                            StoneTypeBadge(type: stone.stoneType.rawValue).frame(width: TableColumn.type, alignment: .leading)
                            Text(String(format: "%.2f", stone.caratWeight)).font(AppTypography.mono).frame(width: TableColumn.carat, alignment: .trailing)
                            Text(stone.color).font(AppTypography.body).frame(width: TableColumn.color, alignment: .leading)
                            Text(stone.shape).font(AppTypography.body).frame(width: TableColumn.shape, alignment: .leading)
                            Text(stone.sellPrice.asCurrency).font(AppTypography.mono).frame(width: TableColumn.price, alignment: .trailing)
                            Spacer()
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
            .padding(AppSpacing.m)
        }
        .frame(minWidth: 720, minHeight: 420)
        .onAppear { fetchStones() }
        .onChange(of: availableOnly) { _, _ in fetchStones() }
    }

    private func fetchStones() {
        let lotGrouping = StoneGrouping.lot
        let availableStatus = GemstoneStatus.available
        let descriptor: FetchDescriptor<Gemstone>
        if availableOnly {
            descriptor = FetchDescriptor<Gemstone>(
                predicate: #Predicate<Gemstone> { $0.grouping != lotGrouping && $0.status == availableStatus },
                sortBy: [SortDescriptor(\.sku)]
            )
        } else {
            descriptor = FetchDescriptor<Gemstone>(
                predicate: #Predicate<Gemstone> { $0.grouping != lotGrouping },
                sortBy: [SortDescriptor(\.sku)]
            )
        }
        fetchedStones = (try? modelContext.fetch(descriptor)) ?? []
    }
}
