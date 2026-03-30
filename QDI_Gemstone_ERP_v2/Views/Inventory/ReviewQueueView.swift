import SwiftUI
import SwiftData

struct ReviewQueueView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allGemstones: [Gemstone]

    init() {
        let soldStatus = GemstoneStatus.sold
        _allGemstones = Query(
            filter: #Predicate<Gemstone> { $0.status != soldStatus },
            sort: \Gemstone.createdAt,
            order: .reverse
        )
    }

    @State private var selectedStoneID: PersistentIdentifier?
    @State private var showEditSheet = false
    @State private var editingStone: Gemstone?
    @State private var searchText = ""

    // MARK: - Computed

    private var reviewStones: [Gemstone] {
        var stones = allGemstones.filter { $0.needsReview }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            stones = stones.filter {
                $0.sku.lowercased().contains(q) ||
                $0.stoneType.rawValue.lowercased().contains(q)
            }
        }
        return stones
    }

    private var currentIndex: Int? {
        guard let id = editingStone?.persistentModelID else { return nil }
        return reviewStones.firstIndex { $0.persistentModelID == id }
    }

    private var hasNext: Bool {
        guard let idx = currentIndex else { return false }
        return idx + 1 < reviewStones.count
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            topBar
            tableContent
        }
        .sheet(isPresented: $showEditSheet) {
            if let stone = editingStone {
                editSheet(stone)
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: AppSpacing.s) {
            GlassSearchField(text: $searchText, placeholder: "Search review queue...")
                .frame(maxWidth: 320)

            Spacer()

            StatusBadge(title: "\(reviewStones.count) needs review", tone: .warning)
        }
        .padding(.horizontal, AppSpacing.l)
        .padding(.vertical, AppSpacing.m)
    }

    // MARK: - Table

    private var tableContent: some View {
        VStack(spacing: 0) {
            tableHeader
            Divider().background(AppColors.cardStroke)

            if reviewStones.isEmpty {
                EmptyStateView(
                    icon: "checkmark.seal",
                    title: "All caught up!",
                    subtitle: "No stones need review"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(reviewStones, id: \.persistentModelID) { stone in
                            reviewRow(stone)
                        }
                    }
                    .padding(.vertical, AppSpacing.xs)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .glassTable()
        .padding(.horizontal, AppSpacing.l)
        .padding(.bottom, AppSpacing.l)
    }

    private var tableHeader: some View {
        HStack(spacing: 0) {
            TableHeader(title: "SKU", width: TableColumn.sku, alignment: .leading)
            TableHeader(title: "Type", width: TableColumn.type, alignment: .leading)
            TableHeader(title: "Shape", width: TableColumn.shape, alignment: .leading)
            TableHeader(title: "Created", width: TableColumn.date, alignment: .leading)
            TableHeader(title: "Missing Fields", alignment: .leading)
            Spacer()
        }
        .padding(.horizontal, AppSpacing.m)
        .padding(.vertical, AppSpacing.s)
    }

    private func reviewRow(_ stone: Gemstone) -> some View {
        HoverRow(isSelected: selectedStoneID == stone.persistentModelID, onTap: {
            selectedStoneID = stone.persistentModelID
            editingStone = stone
            showEditSheet = true
        }) {
            Text(stone.sku)
                .font(AppTypography.mono)
                .foregroundStyle(AppColors.ink)
                .frame(width: TableColumn.sku, alignment: .leading)

            StoneTypeBadge(type: stone.stoneType.rawValue)
                .frame(width: TableColumn.type, alignment: .leading)

            Text(stone.shape.isEmpty ? "--" : stone.shape)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.ink)
                .frame(width: TableColumn.shape, alignment: .leading)

            Text(formattedDate(stone.createdAt))
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.inkMuted)
                .frame(width: TableColumn.date, alignment: .leading)

            missingFieldChips(stone.missingFieldsSummary)

            Spacer()
        }
    }

    // MARK: - Missing Field Chips

    private func missingFieldChips(_ fields: [String]) -> some View {
        HStack(spacing: AppSpacing.xxs) {
            ForEach(fields, id: \.self) { field in
                Text(field)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(chipColor(for: field))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: AppCornerRadius.xs, style: .continuous)
                            .fill(chipColor(for: field).opacity(0.15))
                    )
            }
        }
    }

    private func chipColor(for field: String) -> Color {
        switch field {
        case "Dimensions":      return AppColors.warning
        case "Certificate":     return AppColors.primary
        case "Pricing":         return AppColors.danger
        case "Diamond Grading": return AppColors.accentRose
        default:                return AppColors.inkMuted
        }
    }

    // MARK: - Edit Sheet

    private func editSheet(_ stone: Gemstone) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("Review: \(stone.sku)")
                    .font(AppTypography.heading)
                    .foregroundStyle(AppColors.ink)

                Spacer()

                if hasNext {
                    GradientButton(title: "Save & Next", icon: "arrow.right") {
                        saveAndNext()
                    }
                }

                Button("Done") {
                    showEditSheet = false
                }
                .buttonStyle(.outline)
            }
            .padding(AppSpacing.l)

            StoneFormView(mode: .review(stone))
        }
        .frame(minWidth: 700, minHeight: 500)
        .appBackground()
    }

    private func saveAndNext() {
        do {
            try modelContext.save()
        } catch {
            AppLogger.data.error("Failed to save review: \(error.localizedDescription)")
        }

        guard let idx = currentIndex, idx + 1 < reviewStones.count else {
            showEditSheet = false
            return
        }

        let nextStone = reviewStones[idx + 1]
        editingStone = nextStone
        selectedStoneID = nextStone.persistentModelID
    }

    // MARK: - Helpers

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
