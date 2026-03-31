import SwiftUI
import SwiftData

struct MarginAnalysisView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var report: MarginAnalysisReport?

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.hero) {
            if let report {
                monthlyTrendSection(report)
                HStack(alignment: .top, spacing: AppSpacing.section) {
                    stoneTypeSection(report)
                    distributionSection(report)
                }
            } else {
                ShimmerView()
            }
        }
        .onAppear { loadReport() }
    }

    private func loadReport() {
        report = ReportEngine.generateMarginAnalysis(modelContext: modelContext)
    }

    // MARK: - Monthly Trend (Line Chart)

    private func monthlyTrendSection(_ report: MarginAnalysisReport) -> some View {
        GlassCard(padding: AppSpacing.section) {
            VStack(alignment: .leading, spacing: AppSpacing.section) {
                SectionHeader(title: "Monthly Margin Trend (Last 12 Months)")

                if report.monthlyTrend.isEmpty {
                    EmptyStateView(icon: "chart.line.uptrend.xyaxis", title: "No data", subtitle: "No sales data available")
                } else {
                    let maxMargin = max(report.monthlyTrend.map(\.marginPercent).max() ?? 1, 1)

                    GeometryReader { geo in
                        let width = geo.size.width
                        let height = geo.size.height
                        let stepX = report.monthlyTrend.count > 1 ? width / CGFloat(report.monthlyTrend.count - 1) : width
                        let points = report.monthlyTrend.enumerated().map { i, m in
                            CGPoint(
                                x: CGFloat(i) * stepX,
                                y: height - (CGFloat(m.marginPercent / maxMargin) * height * 0.85) - height * 0.1
                            )
                        }

                        // Grid lines
                        ForEach(0..<4) { i in
                            let y = height * 0.1 + CGFloat(i) * (height * 0.85 / 3)
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: y))
                                path.addLine(to: CGPoint(x: width, y: y))
                            }
                            .stroke(AppColors.cardStroke, lineWidth: 0.5)
                        }

                        // Line
                        Path { path in
                            guard let first = points.first else { return }
                            path.move(to: first)
                            for point in points.dropFirst() {
                                path.addLine(to: point)
                            }
                        }
                        .stroke(AppColors.primary, lineWidth: 2)

                        // Area fill
                        Path { path in
                            guard let first = points.first else { return }
                            path.move(to: CGPoint(x: first.x, y: height))
                            path.addLine(to: first)
                            for point in points.dropFirst() {
                                path.addLine(to: point)
                            }
                            if let last = points.last {
                                path.addLine(to: CGPoint(x: last.x, y: height))
                            }
                            path.closeSubpath()
                        }
                        .fill(
                            LinearGradient(
                                colors: [AppColors.primary.opacity(0.3), AppColors.primary.opacity(0.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        // Data points
                        ForEach(Array(points.enumerated()), id: \.offset) { i, point in
                            Circle()
                                .fill(AppColors.primary)
                                .frame(width: 6, height: 6)
                                .position(point)
                                .accessibilityLabel("\(report.monthlyTrend[i].month): \(String(format: "%.1f%%", report.monthlyTrend[i].marginPercent))")
                        }

                        // Month labels
                        ForEach(Array(report.monthlyTrend.enumerated()), id: \.offset) { i, m in
                            if i % 2 == 0 || report.monthlyTrend.count <= 6 {
                                Text(String(m.month.prefix(3)))
                                    .font(AppTypography.sectionLabel)
                                    .foregroundStyle(AppColors.inkSubtle)
                                    .position(x: CGFloat(i) * stepX, y: height + 10)
                            }
                        }
                    }
                    .frame(height: 200)
                    .padding(.bottom, AppSpacing.hero)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Monthly margin trend chart")
                }
            }
        }
    }

    // MARK: - By Stone Type (Horizontal Bar Chart)

    private func stoneTypeSection(_ report: MarginAnalysisReport) -> some View {
        GlassCard(padding: AppSpacing.section) {
            VStack(alignment: .leading, spacing: AppSpacing.section) {
                SectionHeader(title: "Avg Margin by Stone Type")

                if report.byStoneType.isEmpty {
                    Text("No data")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.inkSubtle)
                } else {
                    let maxMargin = max(report.byStoneType.map(\.avgMarginPercent).max() ?? 1, 1)

                    ForEach(Array(report.byStoneType.enumerated()), id: \.element.id) { index, item in
                        HStack(spacing: AppSpacing.comfortable) {
                            StoneTypeBadge(type: item.stoneType)
                                .frame(width: 90, alignment: .trailing)

                            GeometryReader { geo in
                                let ratio = maxMargin > 0 ? CGFloat(item.avgMarginPercent / maxMargin) : 0
                                RoundedRectangle(cornerRadius: AppCornerRadius.small, style: .continuous)
                                    .fill(AppColors.stoneColor(for: item.stoneType.lowercased()))
                                    .frame(width: max(geo.size.width * ratio, 2))
                            }
                            .frame(height: 20)

                            Text(String(format: "%.1f%%", item.avgMarginPercent))
                                .font(AppTypography.mono)
                                .foregroundStyle(AppColors.ink)
                                .frame(width: 60, alignment: .trailing)
                        }
                        .staggeredRow(index: index, reduceMotion: reduceMotion)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(item.stoneType): average margin \(String(format: "%.1f%%", item.avgMarginPercent))")
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Distribution Histogram

    private func distributionSection(_ report: MarginAnalysisReport) -> some View {
        GlassCard(padding: AppSpacing.section) {
            VStack(alignment: .leading, spacing: AppSpacing.section) {
                SectionHeader(title: "Margin Distribution")

                if report.distribution.isEmpty || report.distribution.allSatisfy({ $0.count == 0 }) {
                    Text("No data")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.inkSubtle)
                } else {
                    let maxCount = max(report.distribution.map(\.count).max() ?? 1, 1)

                    HStack(alignment: .bottom, spacing: AppSpacing.section) {
                        ForEach(Array(report.distribution.enumerated()), id: \.element.id) { index, bucket in
                            VStack(spacing: AppSpacing.standard) {
                                Text("\(bucket.count)")
                                    .font(AppTypography.mono)
                                    .foregroundStyle(AppColors.ink)

                                let ratio = maxCount > 0 ? CGFloat(bucket.count) / CGFloat(maxCount) : 0
                                RoundedRectangle(cornerRadius: AppCornerRadius.small, style: .continuous)
                                    .fill(distributionColor(for: index))
                                    .frame(height: max(ratio * 120, 4))

                                Text(bucket.label)
                                    .font(AppTypography.sectionLabel)
                                    .foregroundStyle(AppColors.inkSubtle)
                                    .multilineTextAlignment(.center)

                                Text(String(format: "%.0f%%", bucket.percent))
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.inkMuted)
                            }
                            .frame(maxWidth: .infinity)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("\(bucket.label): \(bucket.count) stones, \(String(format: "%.0f%%", bucket.percent)) of total")
                        }
                    }
                    .frame(height: 200)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func distributionColor(for index: Int) -> Color {
        switch index {
        case 0: return AppColors.danger
        case 1: return AppColors.warning
        case 2: return AppColors.primary
        default: return AppColors.success
        }
    }
}
