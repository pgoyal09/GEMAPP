import SwiftUI
import SwiftData

struct UnknownTagAssignSheet: View {
    let epc: String
    let tid: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.rfidCoordinator) private var rfidCoordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var allGemstones: [Gemstone]

    init(epc: String, tid: String) {
        self.epc = epc
        self.tid = tid
        // SwiftData #Predicate does not support custom enum types as captured constants.
        // Fetch all and filter in computed property instead.
        _allGemstones = Query(sort: \Gemstone.sku)
    }
    @State private var searchText = ""
    @State private var selectedStoneID: PersistentIdentifier?
    @State private var errorMessage: String?

    private var availableGemstones: [Gemstone] {
        allGemstones.filter { $0.status == .available }
    }

    private var filteredStones: [Gemstone] {
        let q = searchText.lowercased()
        guard !q.isEmpty else { return Array(availableGemstones.prefix(20)) }
        return availableGemstones.filter { $0.sku.lowercased().contains(q) || $0.stoneType.rawValue.lowercased().contains(q) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: AppSpacing.comfortable) {
                Text("Unknown Tag Detected")
                    .font(AppTypography.heading)
                    .foregroundStyle(AppColors.ink)
                GlassCard(padding: AppSpacing.comfortable) {
                    VStack(alignment: .leading, spacing: AppSpacing.tableColumnGap) {
                        DetailRow(label: "EPC", value: epc)
                            .help("Electronic Product Code stored on RFID tags")
                        if !tid.isEmpty { DetailRow(label: "TID", value: tid) }
                    }
                }
            }
            .padding(AppSpacing.hero)

            // Search
            GlassSearchField(text: $searchText, placeholder: "Search by SKU…")
                .padding(.horizontal, AppSpacing.hero)

            // Stone list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredStones) { stone in
                        let isSelected = selectedStoneID == stone.persistentModelID
                        HoverRow(isSelected: isSelected, onTap: { selectedStoneID = stone.persistentModelID }) {
                            Text(stone.sku).font(AppTypography.mono).frame(width: 120, alignment: .leading)
                            StoneTypeBadge(type: stone.stoneType.rawValue)
                            Spacer()
                            Text(stone.rfidEpc == nil ? "No tag" : "Has tag")
                                .font(AppTypography.caption)
                                .foregroundStyle(stone.rfidEpc == nil ? AppColors.inkSubtle : AppColors.warning)
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.section)
            }

            // Footer
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.outline)
                    .accessibilityLabel("Cancel tag assignment")
                Button("Assign Tag") { assignTag() }
                    .buttonStyle(.gradient)
                    .disabled(selectedStoneID == nil)
                    .accessibilityLabel("Assign RFID tag to selected stone")
            }
            .padding(AppSpacing.section)
        }
        .frame(minWidth: 500, minHeight: 400)
        .overlay {
            if let msg = errorMessage {
                ToastOverlay(message: msg, isError: true)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation(reduceMotion ? nil : .default) { errorMessage = nil }
                        }
                    }
            }
        }
        .appBackground()
        
    }

    private func assignTag() {
        guard let id = selectedStoneID,
              let stone = availableGemstones.first(where: { $0.persistentModelID == id }) else { return }
        do {
            try rfidCoordinator?.assignTag(to: stone, modelContext: modelContext)
            dismiss()
        } catch {
            errorMessage = "Failed to assign tag: \(ErrorMapper.userMessage(from: error))"
        }
    }
}
