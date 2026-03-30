import SwiftUI
import SwiftData
import AppKit

struct AccountingView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = AccountingViewModel()
    @State private var selectedTab = 0
    @State private var showExportSuccess = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.l) {
                headerRow
                statCardsRow
                tabSelection
                if selectedTab == 0 { overviewContent } else { transactionsContent }
            }
            .padding(AppSpacing.l)
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
        HStack {
            Text("Internal tracking only — not a substitute for accounting software.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.inkSubtle)
            Spacer()
            Picker("", selection: $viewModel.dateRange) {
                ForEach(AccountingDateRange.allCases, id: \.self) { r in
                    Text(r.rawValue).tag(r)
                }
            }
            .frame(width: 160)
            .accessibilityLabel("Date Range")
            Button("Export CSV") { exportCSV() }
                .buttonStyle(.outline)
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
        VStack(alignment: .leading, spacing: AppSpacing.l) {
            agedReceivablesSection
            salesByTypeSection
        }
    }

    private var agedReceivablesSection: some View {
        GlassCard(padding: AppSpacing.m) {
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                SectionHeader(title: "Aged Receivables")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                    ForEach(viewModel.agedReceivables) { bucket in
                        VStack(spacing: 4) {
                            Text(bucket.amount.asCurrency)
                                .font(AppTypography.subheading)
                                .foregroundStyle(AppColors.ink)
                            Text(bucket.label)
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.inkSubtle)
                            Text("\(bucket.count) invoice\(bucket.count == 1 ? "" : "s")")
                                .font(.system(size: 10))
                                .foregroundStyle(AppColors.inkSubtle)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.s)
                        .background(
                            RoundedRectangle(cornerRadius: AppCornerRadius.s, style: .continuous)
                                .fill(Color.white.opacity(0.03))
                        )
                    }
                }
            }
        }
    }

    private var salesByTypeSection: some View {
        GlassCard(padding: AppSpacing.m) {
            VStack(alignment: .leading, spacing: AppSpacing.m) {
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
        GlassCard(padding: AppSpacing.m) {
            VStack(alignment: .leading, spacing: AppSpacing.m) {
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
                    print("Failed to export CSV: \(error.localizedDescription)")
                }
            }
        }
    }
}
