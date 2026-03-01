import SwiftUI
import SwiftData

/// Sheet to pick a gemstone from inventory; calls onSelect with the chosen stone and dismisses.
struct InventorySelectSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var selectedStoneIDs: Set<PersistentIdentifier> = []
    @State private var searchText = ""
    @State private var stoneTypeFilter: StoneType? = nil  // nil = All
    @State private var availableOnly = true

    var onSelect: ([Gemstone]) -> Void

    /// Base set: all stones, or only available depending on toggle
    private var baseStones: [Gemstone] {
        let descriptor = FetchDescriptor<Gemstone>(
            sortBy: [SortDescriptor(\.sku)]
        )
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
                (stone.clarity.lowercased().contains(q)) ||
                (stone.cut.lowercased().contains(q)) ||
                ((stone.shape ?? "").lowercased().contains(q))
            }
        }
        if let type = stoneTypeFilter {
            result = result.filter { $0.stoneType == type }
        }
        return result
    }

    private var selectedStones: [Gemstone] {
        filteredStones.filter { selectedStoneIDs.contains($0.id) }
    }

    private var hasValidSelection: Bool {
        !selectedStones.isEmpty && selectedStones.allSatisfy { $0.effectiveStatus == .available }
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
                    .frame(maxWidth: 200)

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
                Text("Select Stone\(selectedStoneIDs.count > 1 ? "s" : "")")
                    .font(.headline)
                if !selectedStoneIDs.isEmpty {
                    Text("(\(selectedStoneIDs.count) selected)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(selectedStoneIDs.isEmpty ? "Select" : "Add \(selectedStoneIDs.count) Stone\(selectedStoneIDs.count == 1 ? "" : "s")") {
                    confirmSelection()
                }
                .disabled(!hasValidSelection)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal)

            if filteredStones.isEmpty {
                ContentUnavailableView(
                    availableOnly ? "No Available Stones" : "No Stones Match",
                    systemImage: "diamond",
                    description: Text(availableOnly
                        ? "All stones are on memo or sold. Add stones or return some from memos."
                        : "No stones match your search or filter.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(filteredStones, selection: $selectedStoneIDs) {
                    TableColumn("") { stone in
                        Image(systemName: selectedStoneIDs.contains(stone.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selectedStoneIDs.contains(stone.id) ? Color.accentColor : .secondary)
                    }
                    .width(28)
                    TableColumn("SKU") { stone in
                        Text(stone.sku)
                            .font(.system(.body, design: .monospaced))
                    }
                    .width(100)
                    TableColumn("Type") { stone in Text(stone.stoneType.rawValue) }
                    .width(90)
                    TableColumn("Carat") { stone in
                        Text(String(format: "%.2f", stone.caratWeight))
                            .monospacedDigit()
                    }
                    .width(70)
                    TableColumn("Color") { stone in Text(stone.color) }
                    .width(80)
                    TableColumn("Shape") { stone in Text(shapeDisplay(stone)) }
                    .width(90)
                    TableColumn("Sell Price") { stone in Text(formatCurrency(stone.sellPrice)) }
                    .width(90)
                }
                .onTapGesture(count: 2) {
                    if hasValidSelection {
                        confirmSelection()
                    }
                }
            }
        }
        .frame(minWidth: 720, minHeight: 420)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func confirmSelection() {
        if hasValidSelection {
            onSelect(selectedStones)
        }
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: value as NSDecimalNumber) ?? "$0"
    }
}
