import SwiftUI

struct KPICard: View {
    let title: String
    let value: String
    var unit: String? = nil

    var body: some View {
        GlassCard(padding: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text(title.uppercased())
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.inkSubtle)
                    .tracking(1.2)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(AppTypography.largeValue)
                        .foregroundStyle(AppColors.ink)
                        .contentTransition(.numericText())
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
    }
}

struct KPICardRow: View {
    let viewModel: DashboardViewModel

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 4), spacing: 16) {
            KPICard(title: "Total Carats", value: String(format: "%.2f", viewModel.totalCaratsInStock), unit: "ct")
            KPICard(title: "Value on Memo", value: viewModel.totalValueOnMemo.asCurrencyShort)
            KPICard(title: "Items on Memo", value: "\(viewModel.inventorySnapshot.onMemoCount)")
            KPICard(title: "Available", value: "\(viewModel.inventorySnapshot.availableCount)")
        }
    }
}
