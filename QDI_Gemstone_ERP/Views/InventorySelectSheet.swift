import SwiftUI
import SwiftData

/// Sheet to pick gemstone(s) from inventory.
struct InventorySelectSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var selectedStoneIDs: Set<PersistentIdentifier> = []
    @State private var searchText = ""
    @State private var stoneTypeFilter: StoneType? = nil  // nil = All
    @State private var availableOnly = true

    private let onSelectOne: ((Gemstone) -> Void)?
    private let onSelectMany: (([Gemstone]) -> Void)?

    init(onSelect: @escaping (Gemstone) -> Void) {
        self.onSelectOne = onSelect
        self.onSelectMany = nil
    }

    init(onSelectMany: @escaping ([Gemstone]) -> Void) {
        self.onSelectOne = nil
        self.onSelectMany = onSelectMany
    }

    /// Base set: all stones, or only available depending on toggle
    private var baseStones: [Gemstone] {
        let descriptor = FetchDescriptor<Gemstone>(sortBy: [SortDescriptor(\.sku)])
        guard let all = try? modelContext.fetch(descriptor) else { return [] }
        if availableOnly {
            return all.filter { $0.effectiveStatus == .available }
        }
        return all
    }

    /// Filtered by search and stone type
    private var filteredStones: [Gemstone] {
        var result = baseStones
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            result = result.filter { stone in
                stone.sku.lowercased().contains(q) ||
                stone.stoneType.rawValue.lowercased().contains(q) ||
                stone.color.lowercased().contains(q) ||
                stone.clarity.lowercased().contains(q) ||
                stone.cut.lowercased().contains(q) ||
                (stone.shape ?? "").lowercased().contains(q)
            }
        }
        if let type = stoneTypeFilter {
            result = result.filter { $0.stoneType == type }
        }
        return result
    }

    private var selectedStones: [Gemstone] {
        filteredStones.filter { selectedStoneIDs.contains($0.id) }
            .sorted { $0.sku < $1.sku }
    }

    private func shapeDisplay(_ stone: Gemstone) -> String {
        stone.shape ?? stone.cut
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top controls
            HStack(spacing: 12) {
                TextField("Search…", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 220)

                Picker("Type", selection: $stoneTypeFilter) {
                    Text("All").tag(nil as StoneType?)
                    ForEach(StoneType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type as StoneType?)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 140)

                Toggle("Available only", isOn: $availableOnly)
                    .toggleStyle(.checkbox)
            }
            .padding()

            Divider()

            // Title + buttons
            HStack {
                Text("Select Stone")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Add Selected (\(selectedStones.count))") {
                    confirmSelection()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedStones.isEmpty)
            }
            .padding([.horizontal, .top])
            .padding(.bottom, 8)

            if filteredStones.isEmpty {
                ContentUnavailableView(
                    "No Stones Match",
                    systemImage: "diamond",
                    description: Text("Try a different search or filter.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(filteredStones, selection: $selectedStoneIDs) {
                    TableColumn("SKU") { stone in
                        Text(stone.sku)
                            .font(.system(.body, design: .monospaced))
                    }
                    .width(min: 120, max: 150)

                    TableColumn("Type") { stone in
                        Text(stone.stoneType.rawValue)
                    }
                    .width(min: 90, max: 120)

                    TableColumn("Carat") { stone in
                        Text(String(format: "%.2f", stone.caratWeight))
                            .monospacedDigit()
                    }
                    .width(min: 70, max: 90)

                    TableColumn("Color") { stone in
                        Text(stone.color)
                    }
                    .width(min: 80, max: 120)

                    TableColumn("Shape") { stone in
                        Text(shapeDisplay(stone))
                    }
                    .width(min: 90, max: 120)

                    TableColumn("Status") { stone in
                        Text(stone.effectiveStatus.rawValue)
                            .foregroundStyle(stone.effectiveStatus == .available ? .green : .secondary)
                    }
                    .width(min: 90, max: 120)
                }
                .frame(minHeight: 320)
            }
        }
        .frame(minWidth: 760, minHeight: 540)
    }

    private func confirmSelection() {
        guard !selectedStones.isEmpty else { return }
        if let onSelectMany {
            onSelectMany(selectedStones)
        } else if let onSelectOne, let first = selectedStones.first {
            onSelectOne(first)
        }
        dismiss()
    }
}
