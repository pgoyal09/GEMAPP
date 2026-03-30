import SwiftUI
import SwiftData

struct InventoryAgingView: View {
    @Query(sort: \Gemstone.createdAt) private var allGemstones: [Gemstone]

    private var availableStones: [Gemstone] {
        allGemstones.filter { $0.effectiveStatus == .available && !$0.isLot }
    }

    private struct AgingBucket {
        let label: String
        let range: ClosedRange<Int>
        let color: Color
        var stones: [Gemstone] = []
        var totalCost: Decimal { stones.reduce(0) { $0 + $1.costPrice } }
        var totalSell: Decimal { stones.reduce(0) { $0 + $1.sellPrice } }
        var totalCarats: Double { stones.reduce(0) { $0 + $1.caratWeight } }
    }

    private var buckets: [AgingBucket] {
        let now = Date()
        let cal = Calendar.current
        var b0 = AgingBucket(label: "0–30 days", range: 0...30, color: AppColors.success)
        var b1 = AgingBucket(label: "31–60 days", range: 31...60, color: AppColors.info)
        var b2 = AgingBucket(label: "61–90 days", range: 61...90, color: AppColors.warning)
        var b3 = AgingBucket(label: "91–180 days", range: 91...180, color: AppColors.accentPeach)
        var b4 = AgingBucket(label: "181–365 days", range: 181...365, color: AppColors.danger)
        var b5 = AgingBucket(label: "365+ days", range: 366...99999, color: Color.red)

        for stone in availableStones {
            let days = cal.dateComponents([.day], from: stone.createdAt, to: now).day ?? 0
            switch days {
            case 0...30: b0.stones.append(stone)
            case 31...60: b1.stones.append(stone)
            case 61...90: b2.stones.append(stone)
            case 91...180: b3.stones.append(stone)
            case 181...365: b4.stones.append(stone)
            default: b5.stones.append(stone)
            }
        }
        return [b0, b1, b2, b3, b4, b5]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.l) {
            Text("Inventory Aging Report")
                .font(AppTypography.title)
                .foregroundStyle(AppColors.ink)
                .padding(.horizontal, AppSpacing.l)
                .padding(.top, AppSpacing.l)

            Text("Available stones grouped by days since acquisition")
                .font(AppTypography.body)
                .foregroundStyle(AppColors.inkMuted)
                .padding(.horizontal, AppSpacing.l)

            ScrollView {
                LazyVStack(spacing: AppSpacing.m) {
                    ForEach(Array(buckets.enumerated()), id: \.offset) { _, bucket in
                        HeroCard {
                            VStack(alignment: .leading, spacing: AppSpacing.s) {
                                HStack {
                                    Circle()
                                        .fill(bucket.color)
                                        .frame(width: 10, height: 10)
                                    Text(bucket.label)
                                        .font(AppTypography.heading)
                                        .foregroundStyle(AppColors.ink)
                                    Spacer()
                                    Text("\(bucket.stones.count) stones")
                                        .font(AppTypography.bodyMedium)
                                        .foregroundStyle(bucket.color)
                                }
                                HStack(spacing: AppSpacing.xl) {
                                    agingStat("Carats", value: String(format: "%.2f ct", bucket.totalCarats))
                                    agingStat("Cost", value: bucket.totalCost.asCurrency)
                                    agingStat("Sell Value", value: bucket.totalSell.asCurrency)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.l)
                .padding(.bottom, AppSpacing.xl)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background)
    }

    private func agingStat(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(AppTypography.sectionLabel)
                .foregroundStyle(AppColors.inkSubtle)
                .tracking(1.0)
            Text(value)
                .font(AppTypography.bodyMedium)
                .foregroundStyle(AppColors.ink)
        }
    }
}
