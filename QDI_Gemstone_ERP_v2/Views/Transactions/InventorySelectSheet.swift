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
            .padding(AppSpacing.section)

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
                    }
                    .padding(.horizontal, AppSpacing.section)

                    ForEach(filteredStones) { stone in
                        let isSelected = selectedIDs.contains(stone.persistentModelID)
                        HoverRow(isSelected: isSelected, onTap: {
                            if isSelected { selectedIDs.remove(stone.persistentModelID) }
                            else { selectedIDs.insert(stone.persistentModelID) }
                        }) {
                            Text(stone.sku).font(AppTypography.mono).frame(minWidth: TableColumn.sku, maxWidth: .infinity, alignment: .leading)
                            StoneTypeBadge(type: stone.stoneType.rawValue).frame(minWidth: TableColumn.type, maxWidth: .infinity, alignment: .leading)
                            Text(String(format: "%.2f", stone.caratWeight)).font(AppTypography.mono).frame(minWidth: TableColumn.carat, maxWidth: .infinity, alignment: .trailing)
                            Text(stone.color).font(AppTypography.body).frame(minWidth: TableColumn.color, maxWidth: .infinity, alignment: .leading)
                            Text(stone.shape).font(AppTypography.body).frame(minWidth: TableColumn.shape, maxWidth: .infinity, alignment: .leading)
                            Text(stone.sellPrice.asCurrency).font(AppTypography.mono).frame(minWidth: TableColumn.price, maxWidth: .infinity, alignment: .trailing)
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
