import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

/// Internal accounting overview: total profits, sales by month, aged receivables, sales by stone type.
/// For actual accounting use QuickBooks; this is for sales/memo/inventory tracking.
struct AccountingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Invoice.invoiceDate, order: .reverse) private var allInvoices: [Invoice]

    enum DateRangeOption: String, CaseIterable {
        case allTime = "All time"
        case thisYear = "This year"
        case last12Months = "Last 12 months"
    }
    @State private var vm = AccountingViewModel()
    @State private var showExportSuccess = false
    @State private var selectedTab = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: AppSpacing.s) {
                        Text("Accounting")
                            .font(AppTypography.title)
                            .foregroundStyle(AppColors.ink)
                        Text("Internal tracking only. Use QuickBooks for actual accounting.")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.inkSubtle)
                    }
                    Spacer()
                    Picker("Period", selection: $vm.dateRangeOption) {
                        ForEach(DateRangeOption.allCases, id: \.self) { opt in
                            Text(opt.rawValue).tag(opt)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 160)
                    GradientButton(title: "Export CSV…", icon: "arrow.down.doc") { exportCSV() }
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280))], spacing: AppSpacing.m) {
                    statCard(
                        icon: "chart.line.uptrend.xyaxis",
                        gradient: AppColors.primaryGradient,
                        title: "TOTAL REVENUE",
                        value: vm.totalRevenue,
                        color: AppColors.success
                    )
                    statCard(
                        icon: "dollarsign.arrow.circlepath",
                        gradient: LinearGradient(
                            colors: [Color.white.opacity(0.50), Color.white.opacity(0.30)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        title: "TOTAL COST",
                        value: vm.totalCost,
                        color: AppColors.danger
                    )
                    statCard(
                        icon: "arrow.up.right.circle",
                        gradient: vm.totalProfit >= 0
                            ? LinearGradient(colors: [AppColors.success, Color(red: 0.10, green: 0.65, blue: 0.45)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [AppColors.danger, Color(red: 0.80, green: 0.20, blue: 0.30)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        title: "TOTAL PROFIT",
                        value: vm.totalProfit,
                        color: vm.totalProfit >= 0 ? AppColors.success : AppColors.danger
                    )
                }

                HStack(spacing: AppSpacing.s) {
                    FilterPill(title: "Overview", isActive: selectedTab == 0) { selectedTab = 0 }
                    FilterPill(title: "Transactions", isActive: selectedTab == 1) { selectedTab = 1 }
                }

                if selectedTab == 0 {
                    overviewContent
                } else {
                    transactionsContent
                }
            }
            .padding(AppSpacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.shellGradient)
        .onAppear { vm.load(invoices: allInvoices) }
        .onChange(of: vm.dateRangeOption) { _, _ in vm.load(invoices: allInvoices) }
        .onChange(of: allInvoices.count) { _, _ in vm.load(invoices: allInvoices) }
        .overlay {
            if showExportSuccess {
                VStack {
                    Spacer()
                    Text("Export saved")
                        .font(AppTypography.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, AppSpacing.m)
                        .padding(.vertical, AppSpacing.s)
                        .background(AppColors.success)
                        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.m, style: .continuous))
                        .padding(.bottom, 24)
                }
                .transition(.move(edge: .bottom))
            }
        }
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var overviewContent: some View {
        let aged = vm.agedReceivables

        sectionLabel("Aged Receivables (Open Invoices)")
        GlassCard(padding: AppSpacing.m) {
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                agedRow("0–30 days", aged.current)
                agedRow("31–60 days", aged.days31_60)
                agedRow("61–90 days", aged.days61_90)
                agedRow("Over 90 days", aged.over90)
                Divider().background(AppColors.cardStroke)
                agedRow("Total open", aged.current + aged.days31_60 + aged.days61_90 + aged.over90)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        sectionLabel("Sales by Stone Type")
        GlassCard(padding: AppSpacing.m) {
            if vm.salesByStoneType.isEmpty {
                Text("No sales data")
                    .foregroundStyle(AppColors.inkSubtle)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("TYPE")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.35))
                            .tracking(1.2)
                        Spacer()
                        Text("AMOUNT")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.35))
                            .tracking(1.2)
                    }
                    .padding(.bottom, AppSpacing.s)

                    ForEach(vm.salesByStoneType, id: \.type) { item in
                        HStack {
                            Text(item.type)
                                .font(AppTypography.body)
                                .foregroundStyle(AppColors.ink)
                            Spacer()
                            Text(item.amount, format: .currency(code: "USD"))
                                .font(AppTypography.body)
                                .foregroundStyle(AppColors.success)
                        }
                        .padding(.vertical, AppSpacing.xs)
                        .overlay(alignment: .bottom) {
                            Divider().background(Color.white.opacity(0.04))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var transactionsContent: some View {
        sectionLabel("Sales by Month")
        GlassCard(padding: AppSpacing.m) {
            if vm.salesByMonth.isEmpty {
                Text("No sales data")
                    .foregroundStyle(AppColors.inkSubtle)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("MONTH")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.35))
                            .tracking(1.2)
                        Spacer()
                        Text("REVENUE")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.35))
                            .tracking(1.2)
                    }
                    .padding(.bottom, AppSpacing.s)

                    ForEach(vm.salesByMonth, id: \.month) { entry in
                        HStack {
                            Text(entry.month)
                                .font(AppTypography.body)
                                .foregroundStyle(AppColors.ink)
                            Spacer()
                            Text(entry.amount, format: .currency(code: "USD"))
                                .font(AppTypography.body)
                                .foregroundStyle(AppColors.success)
                        }
                        .padding(.vertical, AppSpacing.xs)
                        .overlay(alignment: .bottom) {
                            Divider().background(Color.white.opacity(0.04))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Helpers

    private func exportCSV() {
        let content = vm.exportCSVContent()
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [UTType.commaSeparatedText]
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        savePanel.nameFieldStringValue = "accounting-export-\(df.string(from: Date())).csv"
        savePanel.begin { response in
            guard response == .OK, let url = savePanel.url else { return }
            do {
                try content.write(to: url, atomically: true, encoding: .utf8)
                showExportSuccess = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { showExportSuccess = false }
            } catch {
                // Could show an error alert
            }
        }
    }

    private func statCard(icon: String, gradient: LinearGradient, title: String, value: Decimal, color: Color) -> some View {
        HeroCard {
            HStack(spacing: AppSpacing.m) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(gradient)
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(title)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.35))
                        .tracking(1.2)
                    Text(value, format: .currency(code: "USD"))
                        .font(AppTypography.heroMetric)
                        .foregroundStyle(color)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Color.white.opacity(0.50))
            .tracking(1.5)
    }

    private func agedRow(_ label: String, _ amount: Decimal) -> some View {
        HStack {
            Text(label)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.ink)
            Spacer()
            Text(amount, format: .currency(code: "USD"))
                .font(AppTypography.body)
                .foregroundStyle(amount > 0 ? AppColors.warning : AppColors.inkMuted)
        }
    }
}
