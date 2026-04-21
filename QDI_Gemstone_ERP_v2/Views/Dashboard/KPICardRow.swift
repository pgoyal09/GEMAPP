import SwiftUI

struct KPICard: View {
    let title: String
    let value: String
    var unit: String? = nil
    var icon: String? = nil

    @State private var pulseScale: CGFloat = 1.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.comfortable) {
            HStack(spacing: AppSpacing.compact) {
                if let icon {
                    Image(systemName: icon)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.inkSubtle)
                }
                Text(title.uppercased())
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.inkSubtle)
                    .tracking(1.5)
            }
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.compact) {
                Text(value)
                    .font(AppTypography.largeValue)
                    .foregroundStyle(AppColors.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
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
        .padding(AppSpacing.hero)
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                        .strokeBorder(AppColors.cardStroke, lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)\(unit.map { " \($0)" } ?? "")")
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
            KPICard(title: "Inventory Value", value: viewModel.totalInventoryValue.asCurrencyShort)
            KPICard(title: "Total Carats", value: String(format: "%.2f", viewModel.totalCaratsInStock), unit: "ct")
            KPICard(title: "Value on Memo", value: viewModel.totalValueOnMemo.asCurrencyShort)
            KPICard(title: "Open Memos", value: "\(viewModel.totalOpenMemoCount)", icon: "doc.text.magnifyingglass")
        }
    }
}
