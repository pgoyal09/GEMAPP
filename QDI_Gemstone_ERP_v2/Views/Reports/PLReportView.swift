import SwiftUI
import SwiftData

struct PLReportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let startDate: Date
    let endDate: Date

    @State private var report: PLReport?

    private static let tableLayout = TableColumnLayout(columns: [
        ColumnDef("stoneType", weight: 2.0, minWidth: 70),
        ColumnDef("units", weight: 1.0, minWidth: 50, alignment: .trailing),
        ColumnDef("revenue", weight: 1.5, minWidth: 65, alignment: .trailing),
        ColumnDef("cogs", weight: 1.5, minWidth: 65, alignment: .trailing),
        ColumnDef("grossProfit", weight: 1.5, minWidth: 65, alignment: .trailing),
        ColumnDef("margin", weight: 1.0, minWidth: 50, alignment: .trailing),
    ], spacing: 4)

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
                    GeometryReader { geo in
                        let widths = Self.tableLayout.widths(for: geo.size.width - 2 * AppSpacing.standard)

                        VStack(alignment: .leading, spacing: 0) {
                            // Header
                            HStack(spacing: 4) {
                                TableHeader(title: "Stone Type", width: widths[0])
                                TableHeader(title: "Units", width: widths[1], alignment: .trailing)
                                TableHeader(title: "Revenue", width: widths[2], alignment: .trailing)
                                TableHeader(title: "COGS", width: widths[3], alignment: .trailing)
                                TableHeader(title: "Gross Profit", width: widths[4], alignment: .trailing)
                                TableHeader(title: "Margin", width: widths[5], alignment: .trailing)
                            }
                            .padding(.horizontal, AppSpacing.standard)
                            .padding(.vertical, AppSpacing.compact)

                            ForEach(Array(report.breakdownByType.enumerated()), id: \.element.id) { index, row in
                                HStack(spacing: 4) {
                                    StoneTypeBadge(type: row.stoneType)
                                        .frame(width: widths[0], alignment: .leading)
                                    Text("\(row.unitsSold)")
                                        .font(AppTypography.mono)
                                        .foregroundStyle(AppColors.ink)
                                        .frame(width: widths[1], alignment: .trailing)
                                    Text(row.revenue.asCurrency)
                                        .font(AppTypography.mono)
                                        .foregroundStyle(AppColors.ink)
                                        .frame(width: widths[2], alignment: .trailing)
                                    Text(row.cogs.asCurrency)
                                        .font(AppTypography.mono)
                                        .foregroundStyle(AppColors.inkMuted)
                                        .frame(width: widths[3], alignment: .trailing)
                                    Text(row.grossProfit.asCurrency)
                                        .font(AppTypography.mono)
                                        .foregroundStyle(row.grossProfit >= 0 ? AppColors.success : AppColors.danger)
                                        .frame(width: widths[4], alignment: .trailing)
                                    Text(String(format: "%.1f%%", row.marginPercent))
                                        .font(AppTypography.mono)
                                        .foregroundStyle(AppColors.ink)
                                        .frame(width: widths[5], alignment: .trailing)
                                }
                                .padding(.horizontal, AppSpacing.standard)
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
    }
}
