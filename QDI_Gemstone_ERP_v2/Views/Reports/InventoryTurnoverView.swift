import SwiftUI
import SwiftData

struct InventoryTurnoverView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let startDate: Date
    let endDate: Date

    @State private var report: InventoryTurnoverReport?

    private static let tableLayout = TableColumnLayout(columns: [
        ColumnDef("sku", weight: 2.0, minWidth: 80),
        ColumnDef("type", weight: 1.5, minWidth: 60),
        ColumnDef("carats", weight: 1.2, minWidth: 55, alignment: .trailing),
        ColumnDef("cost", weight: 1.5, minWidth: 65, alignment: .trailing),
        ColumnDef("days", weight: 1.0, minWidth: 50, alignment: .trailing),
    ], spacing: 4)

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

                VStack(spacing: 0) {
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
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Inventory aging bar chart, \(report.agingBuckets.count) buckets, \(report.agingBuckets.reduce(0) { $0 + $1.count }) total stones")
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
                    GeometryReader { geo in
                        let widths = Self.tableLayout.widths(for: geo.size.width - 2 * AppSpacing.standard)

                        VStack(alignment: .leading, spacing: 0) {
                            HStack(spacing: 4) {
                                TableHeader(title: "SKU", width: widths[0])
                                TableHeader(title: "Type", width: widths[1])
                                TableHeader(title: "Carats", width: widths[2], alignment: .trailing)
                                TableHeader(title: "Cost", width: widths[3], alignment: .trailing)
                                TableHeader(title: "Days", width: widths[4], alignment: .trailing)
                            }
                            .padding(.horizontal, AppSpacing.standard)
                            .padding(.vertical, AppSpacing.compact)

                            ForEach(Array(report.slowMovers.prefix(50).enumerated()), id: \.element.id) { index, stone in
                                HStack(spacing: 4) {
                                    Text(stone.sku)
                                        .font(AppTypography.mono)
                                        .foregroundStyle(AppColors.ink)
                                        .frame(width: widths[0], alignment: .leading)
                                    StoneTypeBadge(type: stone.stoneType)
                                        .frame(width: widths[1], alignment: .leading)
                                    Text(String(format: "%.2f", stone.caratWeight))
                                        .font(AppTypography.mono)
                                        .foregroundStyle(AppColors.ink)
                                        .frame(width: widths[2], alignment: .trailing)
                                    Text(stone.costPrice.asCurrency)
                                        .font(AppTypography.mono)
                                        .foregroundStyle(AppColors.inkMuted)
                                        .frame(width: widths[3], alignment: .trailing)
                                    Text("\(stone.daysInInventory)")
                                        .font(AppTypography.mono)
                                        .foregroundStyle(stone.daysInInventory > 180 ? AppColors.danger : AppColors.warning)
                                        .frame(width: widths[4], alignment: .trailing)
                                }
                                .padding(.horizontal, AppSpacing.standard)
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
    }
}
