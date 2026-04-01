import SwiftUI
import SwiftData
import AppKit

struct AccountingView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = AccountingViewModel()
    @State private var selectedTab = 0
    @State private var showExportSuccess = false
    @State private var showAgingDetail = false
    @State private var selectedAgingBucket: String?
    @State private var customStartDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var customEndDate = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Fetch sent invoices that fall into a specific aging bucket, computed locally.
    private func invoicesForAgingBucket(_ bucketID: String) -> [Invoice] {
        let descriptor = FetchDescriptor<Invoice>()
        guard let invoices = try? modelContext.fetch(descriptor).filter({ $0.status == .sent }) else { return [] }
        let today = Date()
        let calendar = Calendar.current
        return invoices.filter { inv in
            let days = calendar.dateComponents([.day], from: inv.invoiceDate, to: today).day ?? 0
            switch bucketID {
            case "0-30": return days >= 0 && days <= 30
            case "31-60": return days >= 31 && days <= 60
            case "61-90": return days >= 61 && days <= 90
            case "90+": return days > 90
            default: return false
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.hero) {
                headerRow
                quickDateFilters
                statCardsRow
                tabSelection
                if selectedTab == 0 { overviewContent } else { transactionsContent }
            }
            .padding(AppSpacing.hero)
        }
        .onAppear { viewModel.load(modelContext: modelContext) }
        .onChange(of: viewModel.dateRange) { _, _ in viewModel.load(modelContext: modelContext) }
        .overlay {
            if showExportSuccess {
                ToastOverlay(message: "CSV exported successfully")
                    .animation(reduceMotion ? nil : .easeInOut, value: showExportSuccess)
            }
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        VStack(alignment: .trailing, spacing: AppSpacing.comfortable) {
            HStack {
                Text("Internal tracking only — not a substitute for accounting software.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.inkSubtle)
                Spacer()
                Picker("", selection: $viewModel.dateRange) {
                    ForEach(AccountingDateRange.pickerCases, id: \.self) { r in
                        Text(r.displayName).tag(r)
                    }
                }
                .frame(width: 160)
                .accessibilityLabel("Date Range")
                Button("Export CSV") { exportCSV() }
                    .buttonStyle(.outline)
            }
            if viewModel.dateRange.isCustom {
                HStack(spacing: AppSpacing.comfortable) {
                    Spacer()
                    Text("From:")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.inkMuted)
                    DatePicker("", selection: $customStartDate, displayedComponents: .date)
                        .labelsHidden()
                        .frame(width: 130)
                    Text("To:")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.inkMuted)
                    DatePicker("", selection: $customEndDate, displayedComponents: .date)
                        .labelsHidden()
                        .frame(width: 130)
                }
                .onChange(of: customStartDate) { _, newVal in
                    viewModel.dateRange = .custom(from: newVal, to: customEndDate)
                }
                .onChange(of: customEndDate) { _, newVal in
                    viewModel.dateRange = .custom(from: customStartDate, to: newVal)
                }
            }
        }
    }

    // MARK: - Quick Date Filters

    private var quickDateFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.standard) {
                FilterPill(title: "This Month", isActive: isRange(.thisMonth)) {
                    viewModel.dateRange = .thisMonth
                }
                .fixedSize()
                FilterPill(title: "This Quarter", isActive: isRange(.thisQuarter)) {
                    viewModel.dateRange = .thisQuarter
                }
                .fixedSize()
                FilterPill(title: "This Year", isActive: isRange(.thisYear)) {
                    viewModel.dateRange = .thisYear
                }
                .fixedSize()
                FilterPill(title: "All Time", isActive: isRange(.allTime)) {
                    viewModel.dateRange = .allTime
                }
                .fixedSize()
            }
        }
    }

    private func isRange(_ range: AccountingDateRange) -> Bool {
        switch (viewModel.dateRange, range) {
        case (.thisMonth, .thisMonth), (.thisQuarter, .thisQuarter),
             (.thisYear, .thisYear), (.allTime, .allTime):
            return true
        default:
            return false
        }
    }

    // MARK: - Stat Cards

    private var statCardsRow: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: AppSpacing.section), count: 3), spacing: AppSpacing.section) {
            statCard(title: "TOTAL REVENUE", value: viewModel.totalRevenue.asCurrency, color: AppColors.primary)
            statCard(title: "TOTAL COST", value: viewModel.totalCost.asCurrency, color: AppColors.warning)
            profitCard
        }
    }

    private func statCard(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.standard) {
            Text(title)
                .font(AppTypography.sectionLabel)
                .foregroundStyle(AppColors.inkSubtle)
                .tracking(1.2)
            Text(value)
                .font(AppTypography.largeValue)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
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
        .accessibilityLabel("\(title): \(value)")
    }

    private var profitCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.standard) {
            Text("TOTAL PROFIT")
                .font(AppTypography.sectionLabel)
                .foregroundStyle(AppColors.inkSubtle)
                .tracking(1.2)
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.standard) {
                Text(viewModel.totalProfit.asCurrency)
                    .font(AppTypography.largeValue)
                    .foregroundStyle(viewModel.totalProfit >= 0 ? AppColors.success : AppColors.danger)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(String(format: "%.1f%%", viewModel.profitMargin))
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.inkSubtle)
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
        .accessibilityLabel("Total Profit: \(viewModel.totalProfit.asCurrency), margin \(String(format: "%.1f%%", viewModel.profitMargin))")
    }

    // MARK: - Tabs

    private var tabSelection: some View {
        HStack(spacing: AppSpacing.compact) {
            FilterPill(title: "Overview", isActive: selectedTab == 0) { selectedTab = 0 }
            FilterPill(title: "Transactions", isActive: selectedTab == 1) { selectedTab = 1 }
        }
    }

    // MARK: - Overview Tab

    private var overviewContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.hero) {
            agedReceivablesSection
            salesByTypeSection
        }
    }

    private var agedReceivablesSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.section) {
            SectionHeader(title: "Aged Receivables")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: AppSpacing.comfortable), count: 4), spacing: AppSpacing.comfortable) {
                ForEach(viewModel.agedReceivables) { bucket in
                    Button {
                        selectedAgingBucket = bucket.id
                        showAgingDetail = true
                    } label: {
                        VStack(spacing: AppSpacing.compact) {
                            Text(bucket.amount.asCurrency)
                                .font(AppTypography.subheading)
                                .foregroundStyle(AppColors.ink)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Text(bucket.label)
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.inkSubtle)
                            Text("\(bucket.count) invoice\(bucket.count == 1 ? "" : "s")")
                                .font(AppTypography.sectionLabel)
                                .foregroundStyle(AppColors.inkSubtle)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.comfortable)
                        .background(
                            RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                                .fill(AppColors.softHighlight)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(bucket.label) aged receivables: \(bucket.amount.asCurrency), \(bucket.count) invoice\(bucket.count == 1 ? "" : "s")")
                }
            }
        }
        .padding(AppSpacing.hero)
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                        .strokeBorder(AppColors.cardStroke, lineWidth: 1)
                )
        )
        .sheet(isPresented: $showAgingDetail) {
            if let bucketID = selectedAgingBucket {
                AgingBucketDetailSheet(
                    bucketID: bucketID,
                    invoices: invoicesForAgingBucket(bucketID)
                )
            }
        }
    }

    private var salesByTypeSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.section) {
            SectionHeader(title: "Revenue by Stone Type")
            if viewModel.salesByStoneType.isEmpty {
                Text("No sales data")
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.inkSubtle)
            } else {
                let maxRevenue = viewModel.salesByStoneType.map { NSDecimalNumber(decimal: $0.revenue).doubleValue }.max() ?? 1.0
                ForEach(viewModel.salesByStoneType) { row in
                    VStack(alignment: .leading, spacing: AppSpacing.compact) {
                        HStack {
                            StoneTypeBadge(type: row.stoneType)
                            Spacer()
                            Text(row.revenue.asCurrency)
                                .font(AppTypography.mono)
                                .foregroundStyle(AppColors.ink)
                        }
                        GeometryReader { geo in
                            let ratio = maxRevenue > 0 ? NSDecimalNumber(decimal: row.revenue).doubleValue / maxRevenue : 0
                            RoundedRectangle(cornerRadius: AppCornerRadius.field, style: .continuous)
                                .fill(AppColors.primaryGradient)
                                .frame(width: max(geo.size.width * ratio, 4))
                        }
                        .frame(height: 8)
                    }
                    .padding(.vertical, AppSpacing.compact)
                }
            }
        }
        .padding(AppSpacing.hero)
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                        .strokeBorder(AppColors.cardStroke, lineWidth: 1)
                )
        )
    }

    // MARK: - Transactions Tab

    private var transactionsContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.section) {
            SectionHeader(title: "Monthly Revenue")
            if viewModel.monthlySales.isEmpty {
                Text("No sales data")
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.inkSubtle)
            } else {
                let maxMonthlyRevenue = viewModel.monthlySales.map { NSDecimalNumber(decimal: $0.revenue).doubleValue }.max() ?? 1.0
                ForEach(viewModel.monthlySales) { row in
                    VStack(alignment: .leading, spacing: AppSpacing.compact) {
                        HStack {
                            Text(row.month)
                                .font(AppTypography.mono)
                                .foregroundStyle(AppColors.inkMuted)
                            Spacer()
                            Text(row.revenue.asCurrency)
                                .font(AppTypography.mono)
                                .foregroundStyle(AppColors.ink)
                        }
                        GeometryReader { geo in
                            let ratio = maxMonthlyRevenue > 0 ? NSDecimalNumber(decimal: row.revenue).doubleValue / maxMonthlyRevenue : 0
                            RoundedRectangle(cornerRadius: AppCornerRadius.field, style: .continuous)
                                .fill(AppColors.primaryGradient)
                                .frame(width: max(geo.size.width * ratio, 4))
                        }
                        .frame(height: 8)
                    }
                    .padding(.vertical, AppSpacing.compact)
                }
            }
        }
        .padding(AppSpacing.hero)
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                        .strokeBorder(AppColors.cardStroke, lineWidth: 1)
                )
        )
    }

    // MARK: - Export

    private func exportCSV() {
        let csv = viewModel.exportCSV()
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "gemstone_accounting.csv"
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    try csv.write(to: url, atomically: true, encoding: .utf8)
                    showExportSuccess = true
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(2))
                        showExportSuccess = false
                    }
                } catch {
                    AppLogger.data.error("Failed to export CSV: \(error.localizedDescription)")
                }
            }
        }
    }
}
