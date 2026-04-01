import SwiftUI
import SwiftData

enum ReportType: String, CaseIterable {
    case profitLoss = "Profit & Loss"
    case inventoryTurnover = "Inventory Turnover"
    case customerProfitability = "Customer Profitability"
    case marginAnalysis = "Margin Analysis"

    var icon: String {
        switch self {
        case .profitLoss: return "chart.bar.doc.horizontal"
        case .inventoryTurnover: return "arrow.triangle.2.circlepath"
        case .customerProfitability: return "person.2.circle"
        case .marginAnalysis: return "chart.line.uptrend.xyaxis"
        }
    }
}

enum ReportDateRange: Hashable {
    case allTime, thisMonth, thisQuarter, thisYear, custom

    var displayName: String {
        switch self {
        case .allTime: return "All Time"
        case .thisMonth: return "This Month"
        case .thisQuarter: return "This Quarter"
        case .thisYear: return "This Year"
        case .custom: return "Custom"
        }
    }

    var dates: (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()
        switch self {
        case .allTime:
            let start = calendar.date(from: DateComponents(year: 2000, month: 1, day: 1)) ?? now
            return (start, now)
        case .thisMonth:
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
            return (start, now)
        case .thisQuarter:
            let month = calendar.component(.month, from: now)
            let quarterStart = ((month - 1) / 3) * 3 + 1
            var components = calendar.dateComponents([.year], from: now)
            components.month = quarterStart
            components.day = 1
            let start = calendar.date(from: components) ?? now
            return (start, now)
        case .thisYear:
            var components = calendar.dateComponents([.year], from: now)
            components.month = 1
            components.day = 1
            let start = calendar.date(from: components) ?? now
            return (start, now)
        case .custom:
            return (now, now)
        }
    }

    static let allOptions: [ReportDateRange] = [.allTime, .thisMonth, .thisQuarter, .thisYear, .custom]
}

struct ReportsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selectedReport: ReportType = .profitLoss
    @State private var selectedDateRange: ReportDateRange = .allTime
    @State private var customStart = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var customEnd = Date()
    @State private var toastMessage: String?
    @State private var toastIsError = false

    private var effectiveDates: (start: Date, end: Date) {
        if selectedDateRange == .custom {
            return (customStart, customEnd)
        }
        return selectedDateRange.dates
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.hero) {
                controlsBar
                reportContent
            }
            .padding(AppSpacing.hero)
        }
        .overlay {
            if let msg = toastMessage {
                ToastOverlay(message: msg, isError: toastIsError)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation(reduceMotion ? nil : .default) { toastMessage = nil }
                        }
                    }
            }
        }
        .accessibilityIdentifier("ReportsView")
    }

    // MARK: - Controls

    private var controlsBar: some View {
        VStack(alignment: .leading, spacing: AppSpacing.section) {
            // Report type pills
            HStack(spacing: AppSpacing.standard) {
                ForEach(ReportType.allCases, id: \.self) { type in
                    FilterPill(title: type.rawValue, isActive: selectedReport == type) {
                        selectedReport = type
                    }
                    .accessibilityLabel("\(type.rawValue) report")
                }
            }

            // Date range pills + export
            HStack(spacing: AppSpacing.section) {
                HStack(spacing: AppSpacing.standard) {
                    ForEach(ReportDateRange.allOptions, id: \.self) { range in
                        FilterPill(title: range.displayName, isActive: selectedDateRange == range) {
                            selectedDateRange = range
                        }
                    }
                }
                Spacer()
                exportMenu
            }

            // Custom date pickers
            if selectedDateRange == .custom {
                HStack(spacing: AppSpacing.comfortable) {
                    Text("From:")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.inkMuted)
                    DatePicker("", selection: $customStart, displayedComponents: .date)
                        .labelsHidden()
                        .frame(width: 130)
                    Text("To:")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.inkMuted)
                    DatePicker("", selection: $customEnd, displayedComponents: .date)
                        .labelsHidden()
                        .frame(width: 130)
                }
                .padding(AppSpacing.section)
                .background(
                    RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                        .fill(AppColors.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                                .strokeBorder(AppColors.cardStroke, lineWidth: 1)
                        )
                )
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Custom date range")
            }
        }
    }

    private var exportMenu: some View {
        Menu {
            Button("Export CSV") { exportCSV() }
            Button("Export PDF") { exportPDF() }
        } label: {
            Label("Export", systemImage: "square.and.arrow.up")
        }
        .buttonStyle(.outline)
        .accessibilityLabel("Export report")
    }

    // MARK: - Content Router

    @ViewBuilder
    private var reportContent: some View {
        switch selectedReport {
        case .profitLoss:
            PLReportView(startDate: effectiveDates.start, endDate: effectiveDates.end)
        case .inventoryTurnover:
            InventoryTurnoverView(startDate: effectiveDates.start, endDate: effectiveDates.end)
        case .customerProfitability:
            CustomerProfitabilityView(startDate: effectiveDates.start, endDate: effectiveDates.end)
        case .marginAnalysis:
            MarginAnalysisView(startDate: effectiveDates.start, endDate: effectiveDates.end)
        }
    }

    // MARK: - Export Actions

    private func exportCSV() {
        let dates = effectiveDates
        let csv: String
        let filename: String
        switch selectedReport {
        case .profitLoss:
            let report = ReportEngine.generatePLReport(startDate: dates.start, endDate: dates.end, modelContext: modelContext)
            csv = ReportExportService.exportPLToCSV(report)
            filename = "pl_report.csv"
        case .inventoryTurnover:
            let report = ReportEngine.generateInventoryTurnover(startDate: dates.start, endDate: dates.end, modelContext: modelContext)
            csv = ReportExportService.exportInventoryTurnoverToCSV(report)
            filename = "inventory_turnover.csv"
        case .customerProfitability:
            let report = ReportEngine.generateCustomerProfitability(startDate: dates.start, endDate: dates.end, modelContext: modelContext)
            csv = ReportExportService.exportCustomerProfitabilityToCSV(report)
            filename = "customer_profitability.csv"
        case .marginAnalysis:
            let report = ReportEngine.generateMarginAnalysis(startDate: dates.start, endDate: dates.end, modelContext: modelContext)
            csv = ReportExportService.exportMarginAnalysisToCSV(report)
            filename = "margin_analysis.csv"
        }
        ReportExportService.saveCSV(csv, suggestedName: filename)
    }

    private func exportPDF() {
        let dates = effectiveDates
        let dateRange = "\(dates.start.formatted(date: .abbreviated, time: .omitted)) — \(dates.end.formatted(date: .abbreviated, time: .omitted))"
        let html: String
        switch selectedReport {
        case .profitLoss:
            let report = ReportEngine.generatePLReport(startDate: dates.start, endDate: dates.end, modelContext: modelContext)
            html = ReportExportService.buildPLHTML(report, dateRange: dateRange)
        case .inventoryTurnover:
            let report = ReportEngine.generateInventoryTurnover(startDate: dates.start, endDate: dates.end, modelContext: modelContext)
            html = ReportExportService.buildInventoryTurnoverHTML(report, dateRange: dateRange)
        default:
            toastMessage = "PDF export available for P&L and Inventory Turnover"
            toastIsError = false
            return
        }
        ReportExportService.exportReportToPDF(title: selectedReport.rawValue, html: html) { result in
            Task { @MainActor in
                switch result {
                case .success(let url):
                    NSWorkspace.shared.open(url)
                case .failure:
                    toastMessage = "PDF export failed"
                    toastIsError = true
                }
            }
        }
    }
}
