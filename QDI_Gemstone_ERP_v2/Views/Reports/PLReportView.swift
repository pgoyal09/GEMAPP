import SwiftUI
import SwiftData

struct PLReportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let startDate: Date
    let endDate: Date

    @State private var report: PLReport?

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.hero) {
            if let report {
                summaryCards(report)
                breakdownTable(report)
            } else {
                ShimmerView()
            }
        }
        .onAppear { loadReport() }
        .onChange(of: startDate) { _, _ in loadReport() }
        .onChange(of: endDate) { _, _ in loadReport() }
    }

    private func loadReport() {
        report = ReportEngine.generatePLReport(startDate: startDate, endDate: endDate, modelContext: modelContext)
    }

    // MARK: - Summary Cards

    private func summaryCards(_ report: PLReport) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: AppSpacing.section), count: 4), spacing: AppSpacing.section) {
            metricCard(title: "REVENUE", value: report.revenue.asCurrency, color: AppColors.primary)
            metricCard(title: "COGS", value: report.cogs.asCurrency, color: AppColors.warning)
            metricCard(title: "GROSS PROFIT", value: report.grossProfit.asCurrency, color: report.grossProfit >= 0 ? AppColors.success : AppColors.danger)
            metricCard(title: "MARGIN", value: String(format: "%.1f%%", report.marginPercent), color: AppColors.primary)
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

    // MARK: - Breakdown Table

    private func breakdownTable(_ report: PLReport) -> some View {
        GlassCard(padding: AppSpacing.section) {
            VStack(alignment: .leading, spacing: AppSpacing.section) {
                SectionHeader(title: "Breakdown by Stone Type")

                if report.breakdownByType.isEmpty {
                    EmptyStateView(icon: "chart.bar", title: "No sales data", subtitle: "No paid invoices found for this period")
                } else {
                    // Header
                    HStack(spacing: 0) {
                        TableHeader(title: "Stone Type", width: TableColumn.type)
                        TableHeader(title: "Units", width: TableColumn.quantity, alignment: .trailing)
                        TableHeader(title: "Revenue", width: TableColumn.price, alignment: .trailing)
                        TableHeader(title: "COGS", width: TableColumn.price, alignment: .trailing)
                        TableHeader(title: "Gross Profit", width: TableColumn.price, alignment: .trailing)
                        TableHeader(title: "Margin", width: TableColumn.percent, alignment: .trailing)
                    }
                    .padding(.horizontal, AppSpacing.comfortable)

                    ForEach(Array(report.breakdownByType.enumerated()), id: \.element.id) { index, row in
                        HStack(spacing: 0) {
                            StoneTypeBadge(type: row.stoneType)
                                .frame(width: TableColumn.type, alignment: .leading)
                            Text("\(row.unitsSold)")
                                .font(AppTypography.mono)
                                .foregroundStyle(AppColors.ink)
                                .frame(width: TableColumn.quantity, alignment: .trailing)
                            Text(row.revenue.asCurrency)
                                .font(AppTypography.mono)
                                .foregroundStyle(AppColors.ink)
                                .frame(width: TableColumn.price, alignment: .trailing)
                            Text(row.cogs.asCurrency)
                                .font(AppTypography.mono)
                                .foregroundStyle(AppColors.inkMuted)
                                .frame(width: TableColumn.price, alignment: .trailing)
                            Text(row.grossProfit.asCurrency)
                                .font(AppTypography.mono)
                                .foregroundStyle(row.grossProfit >= 0 ? AppColors.success : AppColors.danger)
                                .frame(width: TableColumn.price, alignment: .trailing)
                            Text(String(format: "%.1f%%", row.marginPercent))
                                .font(AppTypography.mono)
                                .foregroundStyle(AppColors.ink)
                                .frame(width: TableColumn.percent, alignment: .trailing)
                        }
                        .padding(.horizontal, AppSpacing.comfortable)
                        .padding(.vertical, AppSpacing.standard)
                        .staggeredRow(index: index, reduceMotion: reduceMotion)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(row.stoneType): \(row.unitsSold) units, revenue \(row.revenue.asCurrency), margin \(String(format: "%.1f%%", row.marginPercent))")
                    }
                }
            }
        }
    }
}
