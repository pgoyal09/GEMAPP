import SwiftUI
import SwiftData

struct ARDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var buckets: [ARAgingBucket] = []
    @State private var overdueCount = 0
    @State private var largestOutstanding: Decimal = 0
    @State private var oldestUnpaidDays = 0
    @State private var totalAR: Decimal = 0
    @State private var toastMessage: String?

    @State private var selectedTab = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.hero) {
                heroCard
                agingSummary
                quickStats
                tabPicker
                if selectedTab == 0 {
                    ARAgingView()
                } else {
                    customerBalancesSection
                }
            }
            .padding(AppSpacing.hero)
        }
        .onAppear { loadData() }
        .overlay {
            if let msg = toastMessage {
                ToastOverlay(message: msg)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation(reduceMotion ? nil : .default) { toastMessage = nil }
                        }
                    }
            }
        }
        .accessibilityIdentifier("ARDashboardView")
    }

    private func loadData() {
        buckets = ARService.agingBuckets(modelContext: modelContext)
        totalAR = buckets.reduce(Decimal.zero) { $0 + $1.totalAmount }
        overdueCount = ARService.overdueInvoices(modelContext: modelContext).count

        let unpaid = ARService.unpaidInvoices(modelContext: modelContext)
        largestOutstanding = unpaid.map(\.balanceDue).max() ?? 0

        let calendar = Calendar.current
        let today = Date()
        oldestUnpaidDays = unpaid.map { inv in
            calendar.dateComponents([.day], from: inv.invoiceDate, to: today).day ?? 0
        }.max() ?? 0
    }

    // MARK: - Hero

    private var heroCard: some View {
        GlassCard(padding: AppSpacing.hero) {
            VStack(alignment: .leading, spacing: AppSpacing.standard) {
                Text("TOTAL OUTSTANDING")
                    .font(AppTypography.sectionLabel)
                    .foregroundStyle(AppColors.inkSubtle)
                    .tracking(1.2)
                Text(totalAR.asCurrency)
                    .font(AppTypography.displayTitle)
                    .foregroundStyle(totalAR > 0 ? AppColors.warning : AppColors.success)
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Total outstanding accounts receivable: \(totalAR.asCurrency)")
        }
    }

    // MARK: - Aging Summary Bars

    private var agingSummary: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: AppSpacing.section), count: buckets.count), spacing: AppSpacing.section) {
            ForEach(Array(buckets.enumerated()), id: \.element.id) { index, bucket in
                GlassCard(padding: AppSpacing.section) {
                    VStack(spacing: AppSpacing.standard) {
                        Text(bucket.totalAmount.asCurrency)
                            .font(AppTypography.subheading)
                            .foregroundStyle(bucketColor(index))
                        Text(bucket.label)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.inkSubtle)
                        Text("\(bucket.count) invoice\(bucket.count == 1 ? "" : "s")")
                            .font(AppTypography.sectionLabel)
                            .foregroundStyle(AppColors.inkSubtle)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(bucket.label): \(bucket.totalAmount.asCurrency), \(bucket.count) invoices")
                }
            }
        }
    }

    private func bucketColor(_ index: Int) -> Color {
        switch index {
        case 0: return AppColors.success
        case 1: return AppColors.warning
        case 2: return AppColors.warningDeep
        case 3: return AppColors.danger.opacity(0.8)
        default: return AppColors.danger
        }
    }

    // MARK: - Quick Stats

    private var quickStats: some View {
        HStack(spacing: AppSpacing.section) {
            statCard(title: "OVERDUE INVOICES", value: "\(overdueCount)", color: AppColors.danger)
            statCard(title: "LARGEST OUTSTANDING", value: largestOutstanding.asCurrency, color: AppColors.warning)
            statCard(title: "OLDEST UNPAID", value: "\(oldestUnpaidDays) days", color: AppColors.warningDeep)
        }
    }

    private func statCard(title: String, value: String, color: Color) -> some View {
        GlassCard(padding: AppSpacing.section) {
            VStack(alignment: .leading, spacing: AppSpacing.compact) {
                Text(title)
                    .font(AppTypography.sectionLabel)
                    .foregroundStyle(AppColors.inkSubtle)
                    .tracking(1)
                Text(value)
                    .font(AppTypography.largeValue)
                    .foregroundStyle(color)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(title): \(value)")
        }
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        HStack(spacing: AppSpacing.standard) {
            FilterPill(title: "Aging Detail", isActive: selectedTab == 0) { selectedTab = 0 }
            FilterPill(title: "By Customer", isActive: selectedTab == 1) { selectedTab = 1 }
        }
    }

    // MARK: - Customer Balances

    private var customerBalancesSection: some View {
        CustomerBalanceView()
    }
}
