import SwiftUI
import SwiftData

struct InventoryTurnoverView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let startDate: Date
    let endDate: Date

    @State private var report: InventoryTurnoverReport?

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.hero) {
            if let report {
                summaryCards(report)
                agingSection(report)
                slowMoversSection(report)
            } else {
                ShimmerView()
            }
        }
        .onAppear { loadReport() }
        .onChange(of: startDate) { _, _ in loadReport() }
        .onChange(of: endDate) { _, _ in loadReport() }
    }

    private func loadReport() {
        report = ReportEngine.generateInventoryTurnover(startDate: startDate, endDate: endDate, modelContext: modelContext)
    }

    // MARK: - Summary Cards

    private func summaryCards(_ report: InventoryTurnoverReport) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: AppSpacing.section), count: 4), spacing: AppSpacing.section) {
            metricCard(title: "INVENTORY COUNT", value: "\(report.currentCount)", color: AppColors.primary)
            metricCard(title: "INVENTORY VALUE", value: report.currentValue.asCurrency, color: AppColors.primary)
            metricCard(title: "SOLD IN PERIOD", value: "\(report.soldCount)", color: AppColors.success)
            metricCard(title: "TURNOVER RATE", value: String(format: "%.2f", report.turnoverRate), color: AppColors.warning)
        }
    }

    private func metricCard(title: String, value: String, color: Color) -> some View {
        GlassCard(padding: AppSpacing.hero) {
            VStack(alignment: .leading, spacing: AppSpacing.standard) {
                Text(title)
                    .font(AppTypography.sectionLabel)
                    .foregroundStyle(AppColors.inkSubtle)
                    .tracking(1.2)
                Text(value)
                    .font(AppTypography.largeValue)
                    .foregroundStyle(color)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(title): \(value)")
        }
    }

    // MARK: - Aging Buckets (Bar Chart)

    private func agingSection(_ report: InventoryTurnoverReport) -> some View {
        GlassCard(padding: AppSpacing.section) {
            VStack(alignment: .leading, spacing: AppSpacing.section) {
                SectionHeader(title: "Inventory Aging")

                let maxCount = report.agingBuckets.map(\.count).max() ?? 1

                ForEach(Array(report.agingBuckets.enumerated()), id: \.element.id) { index, bucket in
                    HStack(spacing: AppSpacing.comfortable) {
                        Text(bucket.label)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.inkMuted)
                            .frame(width: 90, alignment: .trailing)

                        GeometryReader { geo in
                            let ratio = maxCount > 0 ? CGFloat(bucket.count) / CGFloat(maxCount) : 0
                            RoundedRectangle(cornerRadius: AppCornerRadius.small, style: .continuous)
                                .fill(barColor(for: index))
                                .frame(width: max(geo.size.width * ratio, 2))
                        }
                        .frame(height: 24)

                        Text("\(bucket.count)")
                            .font(AppTypography.mono)
                            .foregroundStyle(AppColors.ink)
                            .frame(width: 40, alignment: .trailing)

                        Text(bucket.value.asCurrency)
                            .font(AppTypography.mono)
                            .foregroundStyle(AppColors.inkSubtle)
                            .frame(width: 100, alignment: .trailing)
                    }
                    .staggeredRow(index: index, reduceMotion: reduceMotion)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(bucket.label): \(bucket.count) stones, \(bucket.value.asCurrency)")
                }
            }
        }
    }

    private func barColor(for index: Int) -> Color {
        switch index {
        case 0: return AppColors.success
        case 1: return AppColors.primary
        case 2: return AppColors.warning
        case 3: return AppColors.warningDeep
        default: return AppColors.danger
        }
    }

    // MARK: - Slow Movers

    private func slowMoversSection(_ report: InventoryTurnoverReport) -> some View {
        GlassCard(padding: AppSpacing.section) {
            VStack(alignment: .leading, spacing: AppSpacing.section) {
                SectionHeader(title: "Slow Movers (> 90 Days)")

                if report.slowMovers.isEmpty {
                    Text("No slow-moving inventory")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.inkSubtle)
                        .padding(.vertical, AppSpacing.section)
                } else {
                    HStack(spacing: 0) {
                        TableHeader(title: "SKU", width: TableColumn.sku)
                        TableHeader(title: "Type", width: TableColumn.type)
                        TableHeader(title: "Carats", width: TableColumn.carat, alignment: .trailing)
                        TableHeader(title: "Cost", width: TableColumn.price, alignment: .trailing)
                        TableHeader(title: "Days", width: TableColumn.days, alignment: .trailing)
                    }
                    .padding(.horizontal, AppSpacing.comfortable)

                    ForEach(Array(report.slowMovers.prefix(50).enumerated()), id: \.element.id) { index, stone in
                        HStack(spacing: 0) {
                            Text(stone.sku)
                                .font(AppTypography.mono)
                                .foregroundStyle(AppColors.ink)
                                .frame(width: TableColumn.sku, alignment: .leading)
                            StoneTypeBadge(type: stone.stoneType)
                                .frame(width: TableColumn.type, alignment: .leading)
                            Text(String(format: "%.2f", stone.caratWeight))
                                .font(AppTypography.mono)
                                .foregroundStyle(AppColors.ink)
                                .frame(width: TableColumn.carat, alignment: .trailing)
                            Text(stone.costPrice.asCurrency)
                                .font(AppTypography.mono)
                                .foregroundStyle(AppColors.inkMuted)
                                .frame(width: TableColumn.price, alignment: .trailing)
                            Text("\(stone.daysInInventory)")
                                .font(AppTypography.mono)
                                .foregroundStyle(stone.daysInInventory > 180 ? AppColors.danger : AppColors.warning)
                                .frame(width: TableColumn.days, alignment: .trailing)
                        }
                        .padding(.horizontal, AppSpacing.comfortable)
                        .padding(.vertical, AppSpacing.standard)
                        .staggeredRow(index: index, reduceMotion: reduceMotion)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(stone.sku), \(stone.stoneType), \(stone.daysInInventory) days old")
                    }
                }
            }
        }
    }
}
