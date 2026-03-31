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

    /// Fetch sent invoices that fall into a specific aging bucket, computed locally.
    private func invoicesForAgingBucket(_ bucketID: String) -> [Invoice] {
        let sentStatus = InvoiceStatus.sent
        let descriptor = FetchDescriptor<Invoice>(
            predicate: #Predicate<Invoice> { $0.status == sentStatus }
        )
        guard let invoices = try? modelContext.fetch(descriptor) else { return [] }
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
                    .animation(.easeInOut, value: showExportSuccess)
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
        HStack(spacing: AppSpacing.standard) {
            FilterPill(title: "This Month", isActive: isRange(.thisMonth)) {
                viewModel.dateRange = .thisMonth
            }
            FilterPill(title: "This Quarter", isActive: isRange(.thisQuarter)) {
                viewModel.dateRange = .thisQuarter
            }
            FilterPill(title: "This Year", isActive: isRange(.thisYear)) {
                viewModel.dateRange = .thisYear
            }
            FilterPill(title: "All Time", isActive: isRange(.allTime)) {
                viewModel.dateRange = .allTime
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
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 3), spacing: 16) {
            KPICard(title: "Total Revenue", value: viewModel.totalRevenue.asCurrency)
            KPICard(title: "Total Cost", value: viewModel.totalCost.asCurrency)
            GlassCard(padding: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("TOTAL PROFIT")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.inkSubtle)
                        .tracking(1.2)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(viewModel.totalProfit.asCurrency)
                            .font(AppTypography.largeValue)
                            .foregroundStyle(viewModel.totalProfit >= 0 ? AppColors.success : AppColors.danger)
                        Text(String(format: "%.1f%%", viewModel.profitMargin))
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.inkSubtle)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Tabs

    private var tabSelection: some View {
        HStack(spacing: 6) {
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
        GlassCard(padding: AppSpacing.section) {
            VStack(alignment: .leading, spacing: AppSpacing.section) {
                SectionHeader(title: "Aged Receivables")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                    ForEach(viewModel.agedReceivables) { bucket in
                        Button {
                            selectedAgingBucket = bucket.id
                            showAgingDetail = true
                        } label: {
                            VStack(spacing: 4) {
                                Text(bucket.amount.asCurrency)
                                    .font(AppTypography.subheading)
                                    .foregroundStyle(AppColors.ink)
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
                                RoundedRectangle(cornerRadius: AppCornerRadius.medium, style: .continuous)
                                    .fill(AppColors.softHighlight)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(bucket.label) aged receivables: \(bucket.amount.asCurrency), \(bucket.count) invoice\(bucket.count == 1 ? "" : "s")")
                    }
                }
            }
        }
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
        GlassCard(padding: AppSpacing.section) {
            VStack(alignment: .leading, spacing: AppSpacing.section) {
                SectionHeader(title: "Sales by Stone Type")
                if viewModel.salesByStoneType.isEmpty {
                    Text("No sales data").font(AppTypography.body).foregroundStyle(AppColors.inkSubtle)
                } else {
                    ForEach(viewModel.salesByStoneType) { row in
                        HStack {
                            StoneTypeBadge(type: row.stoneType)
                            Spacer()
                            Text(row.revenue.asCurrency)
                                .font(AppTypography.mono)
                                .foregroundStyle(AppColors.ink)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    // MARK: - Transactions Tab

    private var transactionsContent: some View {
        GlassCard(padding: AppSpacing.section) {
            VStack(alignment: .leading, spacing: AppSpacing.section) {
                SectionHeader(title: "Sales by Month")
                if viewModel.monthlySales.isEmpty {
                    Text("No sales data").font(AppTypography.body).foregroundStyle(AppColors.inkSubtle)
                } else {
                    ForEach(viewModel.monthlySales) { row in
                        HStack {
                            Text(row.month)
                                .font(AppTypography.mono)
                                .foregroundStyle(AppColors.inkMuted)
                            Spacer()
                            Text(row.revenue.asCurrency)
                                .font(AppTypography.mono)
                                .foregroundStyle(AppColors.ink)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
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
