import SwiftUI
import SwiftData

struct ReviewQueueView: View {
    @Query(sort: \Gemstone.createdAt, order: .reverse) private var allGemstones: [Gemstone]
    @State private var selectedStoneID: PersistentIdentifier?
    @State private var showEditSheet = false
    @State private var reviewIndex: Int = 0

    private var reviewStones: [Gemstone] {
        allGemstones.filter { $0.needsReview }
    }

    private var selectedStone: Gemstone? {
        guard let id = selectedStoneID else { return nil }
        return reviewStones.first { $0.id == id }
    }

    private var currentIndex: Int {
        guard let stone = selectedStone else { return 0 }
        return reviewStones.firstIndex(where: { $0.id == stone.id }) ?? 0
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Review Queue")
                    .font(AppTypography.title)
                    .foregroundStyle(AppColors.ink)
                Spacer()
                Text("\(reviewStones.count) need review")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.inkMuted)
                Button("Complete / Edit") {
                    showEditSheet = true
                }
                .buttonStyle(GradientButtonStyle())
                .disabled(selectedStoneID == nil)
                .keyboardShortcut(.return, modifiers: [])
            }
            .padding()
            if reviewStones.isEmpty {
                ContentUnavailableView(
                    "No Items to Review",
                    systemImage: "checkmark.circle",
                    description: Text("Stones with complete follow-up fields will not appear here.")
                )
                .foregroundStyle(AppColors.inkMuted)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                GlassCard(padding: 0) {
                    VStack(spacing: 0) {
                        AppTableHeader(columns: [
                            AppTableHeader.Column("SKU", width: 120),
                            AppTableHeader.Column("TYPE", width: 90),
                            AppTableHeader.Column("SHAPE", width: 100),
                            AppTableHeader.Column("CREATED", width: 110),
                            AppTableHeader.Column("MISSING")
                        ])
                        Divider().background(Color.white.opacity(0.06))
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(reviewStones) { stone in
                                    AppTableHoverRow(
                                        isSelected: selectedStoneID == stone.id,
                                        onTap: { selectedStoneID = stone.id }
                                    ) {
                                        HStack(spacing: 0) {
                                            Text(stone.sku)
                                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                                .foregroundStyle(AppColors.ink)
                                                .lineLimit(1)
                                                .frame(width: 120, alignment: .leading)
                                                .padding(.horizontal, 4)
                                            StoneTypeBadge(type: stone.stoneType.rawValue)
                                                .frame(width: 90, alignment: .leading)
                                                .padding(.horizontal, 4)
                                            Text(stone.shape ?? stone.cut)
                                                .foregroundStyle(AppColors.ink)
                                                .lineLimit(1)
                                                .frame(width: 100, alignment: .leading)
                                                .padding(.horizontal, 4)
                                            Text(stone.createdAt, style: .date)
                                                .foregroundStyle(AppColors.inkMuted)
                                                .frame(width: 110, alignment: .leading)
                                                .padding(.horizontal, 4)
                                            Text(missingFlags(stone))
                                                .font(AppTypography.caption)
                                                .foregroundStyle(AppColors.warning.opacity(0.80))
                                                .lineLimit(1)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.horizontal, 4)
                                        }
                                    }
                                    .onTapGesture(count: 2) {
                                        selectedStoneID = stone.id
                                        showEditSheet = true
                                    }
                                    .contextMenu {
                                        Button("Complete / Edit") {
                                            selectedStoneID = stone.id
                                            showEditSheet = true
                                        }
                                    }
                                    Divider().background(Color.white.opacity(0.03))
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.l)
                .padding(.bottom, AppSpacing.l)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background)
        .sheet(isPresented: $showEditSheet) {
            if let stone = selectedStone {
                NavigationStack {
                    StoneFormView(
                        mode: .review,
                        gemstone: stone,
                        reviewQueue: reviewStones,
                        currentReviewIndex: currentIndex,
                        onSaveAndNext: {
                            let nextIdx = currentIndex + 1
                            if nextIdx < reviewStones.count {
                                selectedStoneID = reviewStones[nextIdx].id
                            } else {
                                showEditSheet = false
                            }
                        },
                        onDismiss: { showEditSheet = false }
                    )
                    .frame(minWidth: 624, minHeight: 540)
                    .navigationTitle("Review: \(stone.sku)")
                }
                .id(stone.id)
            }
        }
    }

    private func missingFlags(_ stone: Gemstone) -> String {
        var flags: [String] = []
        if stone.missingDimensions { flags.append("Dimensions") }
        if stone.missingCertDetails { flags.append("Cert") }
        if stone.missingCost { flags.append("Cost") }
        if stone.missingSellPrice { flags.append("Sell Price") }
        if stone.missingDiamondGrading { flags.append("Diamond Grading") }
        return flags.joined(separator: ", ")
    }
}
