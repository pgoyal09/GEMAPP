import SwiftUI
import SwiftData

struct CustomerProfitabilityView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let startDate: Date
    let endDate: Date

    @State private var report: CustomerProfitabilityReport?
    @State private var selectedCustomerId: PersistentIdentifier?
    @State private var searchText = ""

    private static let tableLayout = TableColumnLayout(columns: [
        ColumnDef("customer", weight: 2.5, minWidth: 100),
        ColumnDef("revenue", weight: 1.5, minWidth: 65, alignment: .trailing),
        ColumnDef("cogs", weight: 1.5, minWidth: 65, alignment: .trailing),
        ColumnDef("profit", weight: 1.5, minWidth: 65, alignment: .trailing),
        ColumnDef("margin", weight: 1.0, minWidth: 50, alignment: .trailing),
        ColumnDef("count", weight: 0.8, minWidth: 40, alignment: .trailing),
        ColumnDef("avgOrder", weight: 1.5, minWidth: 65, alignment: .trailing),
    ], spacing: 4)

    private var filteredRows: [CustomerProfitRow] {
        guard let report else { return [] }
        if searchText.isEmpty { return report.rows }
        return report.rows.filter { $0.customerName.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        HStack(spacing: 0) {
            tableSection
            if selectedCustomerId != nil {
                Divider().background(AppColors.cardStroke)
                customerDetail
            }
        }
        .onAppear { loadReport() }
        .onChange(of: startDate) { _, _ in loadReport() }
        .onChange(of: endDate) { _, _ in loadReport() }
    }

    private func loadReport() {
        report = ReportEngine.generateCustomerProfitability(startDate: startDate, endDate: endDate, modelContext: modelContext)
    }

    // MARK: - Table

    private var tableSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.section) {
            GlassSearchField(text: $searchText, placeholder: "Search customers...")
                .padding(.horizontal, AppSpacing.section)

            GlassCard(padding: AppSpacing.section) {
                VStack(alignment: .leading, spacing: AppSpacing.section) {
                    SectionHeader(title: "Customer Profitability")

                    if filteredRows.isEmpty {
                        EmptyStateView(icon: "person.2", title: "No customer data", subtitle: "No paid invoices found for this period")
                    } else {
                        GeometryReader { geo in
                            let widths = Self.tableLayout.widths(for: geo.size.width - 2 * AppSpacing.standard)

                            VStack(alignment: .leading, spacing: 0) {
                                // Header row
                                HStack(spacing: 4) {
                                    TableHeader(title: "Customer", width: widths[0])
                                    TableHeader(title: "Revenue", width: widths[1], alignment: .trailing)
                                    TableHeader(title: "COGS", width: widths[2], alignment: .trailing)
                                    TableHeader(title: "Profit", width: widths[3], alignment: .trailing)
                                    TableHeader(title: "Margin", width: widths[4], alignment: .trailing)
                                    TableHeader(title: "#", width: widths[5], alignment: .trailing)
                                    TableHeader(title: "Avg Order", width: widths[6], alignment: .trailing)
                                }
                                .padding(.horizontal, AppSpacing.standard)
                                .padding(.vertical, AppSpacing.compact)

                                ScrollView {
                                    LazyVStack(spacing: 0) {
                                        ForEach(Array(filteredRows.enumerated()), id: \.element.id) { index, row in
                                            let isTop10 = index < 10
                                            let isBottom10 = filteredRows.count > 20 && index >= filteredRows.count - 10

                                            HoverRow(isSelected: selectedCustomerId == row.customerId) {
                                                selectedCustomerId = row.customerId
                                            } content: {
                                                HStack(spacing: 4) {
                                                    HStack(spacing: AppSpacing.standard) {
                                                        if isTop10 {
                                                            Image(systemName: "star.fill")
                                                                .font(.caption2)
                                                                .foregroundStyle(AppColors.warning)
                                                        }
                                                        Text(row.customerName)
                                                            .font(AppTypography.body)
                                                            .foregroundStyle(AppColors.ink)
                                                            .lineLimit(1)
                                                    }
                                                    .frame(width: widths[0], alignment: .leading)

                                                    Text(row.totalRevenue.asCurrency)
                                                        .font(AppTypography.mono)
                                                        .foregroundStyle(AppColors.ink)
                                                        .frame(width: widths[1], alignment: .trailing)

                                                    Text(row.totalCOGS.asCurrency)
                                                        .font(AppTypography.mono)
                                                        .foregroundStyle(AppColors.inkMuted)
                                                        .frame(width: widths[2], alignment: .trailing)

                                                    Text(row.profit.asCurrency)
                                                        .font(AppTypography.mono)
                                                        .foregroundStyle(row.profit >= 0 ? AppColors.success : AppColors.danger)
                                                        .frame(width: widths[3], alignment: .trailing)

                                                    Text(String(format: "%.1f%%", row.marginPercent))
                                                        .font(AppTypography.mono)
                                                        .foregroundStyle(AppColors.ink)
                                                        .frame(width: widths[4], alignment: .trailing)

                                                    Text("\(row.transactionCount)")
                                                        .font(AppTypography.mono)
                                                        .foregroundStyle(AppColors.ink)
                                                        .frame(width: widths[5], alignment: .trailing)

                                                    Text(row.avgOrderValue.asCurrency)
                                                        .font(AppTypography.mono)
                                                        .foregroundStyle(AppColors.inkSubtle)
                                                        .frame(width: widths[6], alignment: .trailing)
                                                }
                                            }
                                            .staggeredRow(index: index, reduceMotion: reduceMotion)
                                            .accessibilityElement(children: .combine)
                                            .accessibilityLabel("\(row.customerName): profit \(row.profit.asCurrency), margin \(String(format: "%.1f%%", row.marginPercent))")
                                            .accessibilityHint(isTop10 ? "Top 10 customer" : isBottom10 ? "Bottom 10 customer" : "")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Customer Detail Panel

    private var customerDetail: some View {
        VStack(alignment: .leading, spacing: AppSpacing.section) {
            if let custId = selectedCustomerId,
               let customer: Customer = try? modelContext.fetch(FetchDescriptor<Customer>()).first(where: { $0.persistentModelID == custId }) {
                GlassCard(padding: AppSpacing.hero) {
                    VStack(alignment: .leading, spacing: AppSpacing.comfortable) {
                        Text(customer.displayName)
                            .font(AppTypography.heading)
                            .foregroundStyle(AppColors.ink)
                        if !customer.company.isEmpty {
                            Text(customer.company)
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.inkSubtle)
                        }
                    }
                }

                SectionHeader(title: "Transaction History")
                    .padding(.horizontal, AppSpacing.section)

                ScrollView {
                    LazyVStack(spacing: AppSpacing.standard) {
                        ForEach(customer.invoices.filter { $0.status == .paid }.sorted(by: { $0.invoiceDate > $1.invoiceDate })) { invoice in
                            GlassCard(padding: AppSpacing.comfortable) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(invoice.referenceNumber)
                                            .font(AppTypography.mono)
                                            .foregroundStyle(AppColors.ink)
                                        Text(invoice.invoiceDate.formatted(date: .abbreviated, time: .omitted))
                                            .font(AppTypography.caption)
                                            .foregroundStyle(AppColors.inkSubtle)
                                    }
                                    Spacer()
                                    Text(invoice.grandTotal.asCurrency)
                                        .font(AppTypography.body)
                                        .foregroundStyle(AppColors.ink)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.section)
                }
            } else {
                EmptyStateView(icon: "person.crop.circle", title: "Select a customer", subtitle: "Click a row to see details")
            }
        }
        .frame(minWidth: 260, idealWidth: 296, maxWidth: 360)
    }
}
