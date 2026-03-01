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
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(reviewStones.count) need review")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            if reviewStones.isEmpty {
                ContentUnavailableView(
                    "No Items to Review",
                    systemImage: "checkmark.circle",
                    description: Text("Stones with complete follow-up fields will not appear here.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(reviewStones, selection: $selectedStoneID) {
                    TableColumn("SKU") { s in Text(s.sku) }
                    TableColumn("Type") { s in Text(s.stoneType.rawValue) }
                    TableColumn("Shape") { s in Text(s.shape ?? s.cut) }
                    TableColumn("Created") { s in Text(s.createdAt, style: .date) }
                    TableColumn("Missing") { s in
                        Text(missingFlags(s))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .tableStyle(.bordered(alternatesRowBackgrounds: true))
                .contextMenu(forSelectionType: PersistentIdentifier.self) { items in
                    if items.first != nil {
                        Button("Complete / Edit") {
                            showEditSheet = true
                        }
                    }
                } primaryAction: { items in
                    if items.first != nil {
                        showEditSheet = true
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
