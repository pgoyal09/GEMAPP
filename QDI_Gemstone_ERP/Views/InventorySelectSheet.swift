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

    /// Base set: non-lot stones only (lots are handled by LotSelectSheet).
    private var baseStones: [Gemstone] {
        let descriptor = FetchDescriptor<Gemstone>(
            sortBy: [SortDescriptor(\.sku)]
        )
        guard let all = try? modelContext.fetch(descriptor) else { return [] }
        let singles = all.filter { !$0.isLot }
        if availableOnly {
            return singles.filter { $0.effectiveStatus == .available }
        }
        return singles
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
            HStack(spacing: 12) {
                TextField("Search…", text: $searchText)
                    .glassField()
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
                    .foregroundStyle(AppColors.inkMuted)
            }
            .padding()

            Divider().overlay(AppColors.cardStroke)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Select Stone\(selectedStoneIDs.count > 1 ? "s" : "")")
                        .font(.headline)
                        .foregroundStyle(AppColors.ink)
                    Text("Click to select multiple")
                        .font(.caption2)
                        .foregroundStyle(AppColors.inkMuted)
                }
                if !selectedStoneIDs.isEmpty {
                    Text("(\(selectedStoneIDs.count) selected)")
                        .font(.caption)
                        .foregroundStyle(AppColors.inkMuted)
                }
                Spacer()
                Button(selectedStoneIDs.isEmpty ? "Select" : "Add \(selectedStoneIDs.count) Stone\(selectedStoneIDs.count == 1 ? "" : "s")") {
                    confirmSelection()
                }
                .disabled(!hasValidSelection)
                .buttonStyle(GradientButtonStyle())
                .keyboardShortcut(.defaultAction)
                Button("Cancel") { dismiss() }
                    .buttonStyle(OutlineGlassButtonStyle())
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
                .foregroundStyle(AppColors.inkMuted)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        inventoryHeader
                        Divider().overlay(AppColors.cardStroke)
                        ForEach(filteredStones, id: \.id) { stone in
                            inventoryRow(stone)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    toggleSelection(stone)
                                }
                                .onTapGesture(count: 2) {
                                    if hasValidSelection { confirmSelection() }
                                }
                        }
                    }
                }
            }
        }
        .frame(minWidth: 720, minHeight: 420)
        .background(AppColors.background)
    }

    private var inventoryHeader: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: 28)
            Text("SKU").font(.caption.bold()).foregroundStyle(AppColors.inkSubtle).frame(width: 100, alignment: .leading)
            Text("Type").font(.caption.bold()).foregroundStyle(AppColors.inkSubtle).frame(width: 90, alignment: .leading)
            Text("Carat").font(.caption.bold()).foregroundStyle(AppColors.inkSubtle).frame(width: 70, alignment: .trailing)
            Text("Color").font(.caption.bold()).foregroundStyle(AppColors.inkSubtle).frame(width: 80, alignment: .leading)
            Text("Shape").font(.caption.bold()).foregroundStyle(AppColors.inkSubtle).frame(width: 90, alignment: .leading)
            Text("Sell Price").font(.caption.bold()).foregroundStyle(AppColors.inkSubtle).frame(width: 90, alignment: .trailing)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .background(AppColors.cardBackground)
    }

    private func toggleSelection(_ stone: Gemstone) {
        if selectedStoneIDs.contains(stone.id) {
            selectedStoneIDs.remove(stone.id)
        } else {
            selectedStoneIDs.insert(stone.id)
        }
    }

    private func confirmSelection() {
        if hasValidSelection {
            onSelect(selectedStones)
        }
    }

    private func inventoryRow(_ stone: Gemstone) -> some View {
        let isSelected = selectedStoneIDs.contains(stone.id)
        return HStack(spacing: 0) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? AppColors.primary : AppColors.inkSubtle)
                .frame(width: 28, alignment: .center)
            Text(stone.sku)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(AppColors.ink)
                .frame(width: 100, alignment: .leading)
            Text(stone.stoneType.rawValue)
                .foregroundStyle(AppColors.ink)
                .frame(width: 90, alignment: .leading)
            Text(String(format: "%.2f", stone.caratWeight))
                .monospacedDigit()
                .foregroundStyle(AppColors.ink)
                .frame(width: 70, alignment: .trailing)
            Text(stone.color)
                .foregroundStyle(AppColors.ink)
                .frame(width: 80, alignment: .leading)
            Text(shapeDisplay(stone))
                .foregroundStyle(AppColors.ink)
                .frame(width: 90, alignment: .leading)
            Text(stone.sellPrice.asCurrency)
                .foregroundStyle(AppColors.ink)
                .frame(width: 90, alignment: .trailing)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(isSelected ? AppColors.primary.opacity(0.10) : Color.clear)
    }

}
