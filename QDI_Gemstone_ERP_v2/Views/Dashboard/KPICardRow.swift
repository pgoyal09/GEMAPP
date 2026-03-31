import SwiftUI

struct KPICard: View {
    let title: String
    let value: String
    var unit: String? = nil

    @State private var pulseScale: CGFloat = 1.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GlassCard(padding: AppSpacing.hero) {
            VStack(alignment: .leading, spacing: AppSpacing.comfortable) {
                Text(title.uppercased())
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.inkSubtle)
                    .tracking(1.2)
                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.compact) {
                    Text(value)
                        .font(AppTypography.largeValue)
                        .foregroundStyle(AppColors.ink)
                        .contentTransition(.numericText())
                        .scaleEffect(pulseScale)
                    if let unit {
                        Text(unit)
                            .font(AppTypography.body)
                            .foregroundStyle(AppColors.inkSubtle)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(title): \(value)\(unit.map { " \($0)" } ?? "")")
        }
        .onChange(of: value) { _, _ in
            guard !reduceMotion else { return }
            withAnimation(AppAnimation.pulse) {
                pulseScale = 1.05
            }
            withAnimation(AppAnimation.pulse.delay(0.15)) {
                pulseScale = 1.0
            }
        }
    }
}

struct KPICardRow: View {
    let viewModel: DashboardViewModel

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: AppSpacing.section), count: 4), spacing: AppSpacing.section) {
            KPICard(title: "Total Carats", value: String(format: "%.2f", viewModel.totalCaratsInStock), unit: "ct")
            KPICard(title: "Value on Memo", value: viewModel.totalValueOnMemo.asCurrencyShort)
            KPICard(title: "Items on Memo", value: "\(viewModel.inventorySnapshot.onMemoCount)")
            KPICard(title: "Available", value: "\(viewModel.inventorySnapshot.availableCount)")
        }
    }
}
