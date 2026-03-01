import SwiftUI
import SwiftData

/// Modal to assign an unknown RFID tag to a stone in inventory.
struct UnknownTagAssignSheet: View {
    let epc: String
    let tid: String?
    var onDismiss: () -> Void
    var onAssigned: (Gemstone) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var selectedStoneID: PersistentIdentifier?
    @State private var searchText = ""
    @State private var errorMessage: String?
    @State private var showReplaceConfirm = false
    @State private var pendingStone: Gemstone?
    @State private var assignSuccess = false

    private var baseStones: [Gemstone] {
        let descriptor = FetchDescriptor<Gemstone>(sortBy: [SortDescriptor(\.sku)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

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
        return result
    }

    private var selectedStone: Gemstone? {
        guard let id = selectedStoneID else { return nil }
        return filteredStones.first { $0.id == id }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Unknown tag detected")
                    .font(AppTypography.heading)
                    .foregroundStyle(AppColors.ink)
                Text("Assign this tag to a stone in inventory.")
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.inkSubtle)
                HStack(spacing: 8) {
                    Text("Tag EPC:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(epc)
                        .font(AppTypography.mono)
                        .foregroundStyle(AppColors.ink)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                 .background(AppColors.cardElevated)
                .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.m, style: .continuous))
            }
            .padding()

            Divider()

            // Search
            HStack {
                TextField("Search SKU, type, color…", text: $searchText)
                     .appSearchField()
                    .frame(maxWidth: 200)
            }
            .padding()

            if let err = errorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            // Stone table
            if filteredStones.isEmpty {
                ContentUnavailableView("No Stones Match", systemImage: "diamond", description: Text("Try a different search."))
                    .frame(maxWidth: .infinity, maxHeight: 280)
            } else {
                Table(filteredStones, selection: $selectedStoneID) {
                    TableColumn("") { stone in
                        Image(systemName: selectedStoneID == stone.id ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selectedStoneID == stone.id ? Color.accentColor : .secondary)
                    }
                    .width(28)
                    TableColumn("SKU") { Text($0.sku).font(AppTypography.mono)
                        .foregroundStyle(AppColors.ink) }
                    .width(100)
                    TableColumn("Type") { Text($0.stoneType.rawValue) }
                    .width(90)
                    TableColumn("Carat") { Text(String(format: "%.2f", $0.caratWeight)).monospacedDigit() }
                    .width(70)
                    TableColumn("Color") { Text($0.color) }
                    .width(80)
                    TableColumn("Shape") { Text($0.shape ?? $0.cut) }
                    .width(90)
                    TableColumn("RFID") { stone in
                        let hasRfid = stone.effectiveRfidEpc != nil
                        Text(hasRfid ? "Assigned" : "—")
                            .foregroundStyle(hasRfid ? .orange : .secondary)
                    }
                    .width(80)
                }
                .frame(minHeight: 200, maxHeight: 320)
            }

            Divider()

            // Buttons
            HStack {
                Spacer()
                if assignSuccess {
                    Text("Assigned successfully")
                        .foregroundStyle(.green)
                        .font(.subheadline)
                    Spacer()
                }
                Button("Cancel") {
                    onDismiss()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button("Assign") {
                    attemptAssign()
                }
                .disabled(selectedStone == nil)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(minWidth: 700, minHeight: 520)
        .background(AppColors.background)
        .alert("Replace existing RFID?", isPresented: $showReplaceConfirm) {
            Button("Cancel", role: .cancel) {
                pendingStone = nil
            }
            Button("Replace", role: .destructive) {
                if let stone = pendingStone {
                    performAssign(to: stone, replaceExisting: true)
                }
                pendingStone = nil
            }
        } message: {
            Text("This stone already has an RFID tag. Replacing will assign the scanned tag instead.")
        }
    }

    private func attemptAssign() {
        guard let stone = selectedStone else { return }
        errorMessage = nil

        let hasExisting = stone.effectiveRfidEpc != nil
        if hasExisting {
            pendingStone = stone
            showReplaceConfirm = true
        } else {
            performAssign(to: stone, replaceExisting: false)
        }
    }

    private func performAssign(to stone: Gemstone, replaceExisting: Bool) {
        let result = RFIDScanService.assignTagToStone(
            epc: epc,
            tid: tid,
            stone: stone,
            replaceExisting: replaceExisting,
            modelContext: modelContext
        )

        switch result {
        case .assigned, .replaced:
            assignSuccess = true
            onAssigned(stone)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                dismiss()
                onDismiss()
            }
        case .conflict(let msg):
            errorMessage = msg
        }
    }
}
