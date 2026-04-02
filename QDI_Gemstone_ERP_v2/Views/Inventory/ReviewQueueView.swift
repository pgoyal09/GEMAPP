import SwiftUI
import SwiftData

struct ReviewQueueView: View {
    // MARK: - Table Layout

    private static let tableLayout = TableColumnLayout(columns: [
        ColumnDef("sku", weight: 2.0, minWidth: 80),
        ColumnDef("type", weight: 1.5, minWidth: 60),
        ColumnDef("shape", weight: 1.5, minWidth: 60),
        ColumnDef("created", weight: 1.5, minWidth: 70),
        ColumnDef("missing", weight: 3.0, minWidth: 120),
    ], spacing: 4)

    @Environment(\.modelContext) private var modelContext
    @Query private var allGemstones: [Gemstone]

    init() {
        // SwiftData #Predicate does not support custom enum types as captured constants.
        // Fetch all and filter in computed property instead.
        _allGemstones = Query(sort: \Gemstone.createdAt, order: .reverse)
    }

    @State private var selectedStoneID: PersistentIdentifier?
    @State private var showEditSheet = false
    @State private var editingStone: Gemstone?
    @State private var searchText = ""

    // MARK: - Computed

    private var reviewStones: [Gemstone] {
        var stones = allGemstones.filter { $0.status != .sold && $0.needsReview }
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
        HStack(spacing: AppSpacing.comfortable) {
            GlassSearchField(text: $searchText, placeholder: "Search review queue...")
                .frame(maxWidth: 320)

            Spacer()

            StatusBadge(title: "\(reviewStones.count) needs review", tone: .warning)
        }
        .padding(.horizontal, AppSpacing.hero)
        .padding(.vertical, AppSpacing.section)
    }

    // MARK: - Table

    private var tableContent: some View {
        GeometryReader { geo in
            let widths = Self.tableLayout.widths(for: geo.size.width - 2 * AppSpacing.section)
            VStack(spacing: 0) {
                tableHeader(widths: widths)
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
                                reviewRow(stone, widths: widths)
                            }
                        }
                        .padding(.vertical, AppSpacing.standard)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(AppColors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(AppColors.cardStroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .padding(.horizontal, AppSpacing.hero)
        .padding(.bottom, AppSpacing.hero)
    }

    private func tableHeader(widths: [CGFloat]) -> some View {
        HStack(spacing: 4) {
            TableHeader(title: "SKU", width: widths[0], alignment: .leading)
            TableHeader(title: "Type", width: widths[1], alignment: .leading)
            TableHeader(title: "Shape", width: widths[2], alignment: .leading)
            TableHeader(title: "Created", width: widths[3], alignment: .leading)
            TableHeader(title: "Missing Fields", width: widths[4], alignment: .leading)
        }
        .padding(.horizontal, AppSpacing.section)
        .padding(.vertical, AppSpacing.comfortable)
    }

    private func reviewRow(_ stone: Gemstone, widths: [CGFloat]) -> some View {
        HoverRow(isSelected: selectedStoneID == stone.persistentModelID, onTap: {
            selectedStoneID = stone.persistentModelID
            editingStone = stone
            showEditSheet = true
        }) {
            Text(stone.sku)
                .font(AppTypography.mono)
                .foregroundStyle(AppColors.ink)
                .frame(width: widths[0], alignment: .leading)

            StoneTypeBadge(type: stone.stoneType.rawValue)
                .frame(width: widths[1], alignment: .leading)

            Text(stone.shape.isEmpty ? "--" : stone.shape)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.ink)
                .frame(width: widths[2], alignment: .leading)

            Text(formattedDate(stone.createdAt))
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.inkMuted)
                .frame(width: widths[3], alignment: .leading)

            missingFieldChips(stone.missingFieldsSummary)
                .frame(width: widths[4], alignment: .leading)
        }
    }

    // MARK: - Missing Field Chips

    private func missingFieldChips(_ fields: [String]) -> some View {
        HStack(spacing: AppSpacing.compact) {
            ForEach(fields, id: \.self) { field in
                Text(field)
                    .font(AppTypography.sectionLabel.weight(.medium))
                    .foregroundStyle(chipColor(for: field))
                    .padding(.horizontal, AppSpacing.compact)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: AppCornerRadius.small, style: .continuous)
                            .fill(chipColor(for: field).opacity(AppOpacity.muted))
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
                    Button("Save & Next", systemImage: "arrow.right") {
                        saveAndNext()
                    }.buttonStyle(.gradient)
                }

                Button("Done") {
                    showEditSheet = false
                }
                .buttonStyle(.outline)
            }
            .padding(AppSpacing.hero)

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
