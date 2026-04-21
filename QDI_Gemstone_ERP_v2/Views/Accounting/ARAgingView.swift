import SwiftUI
import SwiftData

struct ARAgingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let tableLayout = TableColumnLayout(columns: [
        ColumnDef("invoice", weight: 1.5, minWidth: 70),
        ColumnDef("customer", weight: 2.5, minWidth: 100),
        ColumnDef("amount", weight: 1.5, minWidth: 65, alignment: .trailing),
        ColumnDef("paid", weight: 1.5, minWidth: 65, alignment: .trailing),
        ColumnDef("balance", weight: 1.5, minWidth: 65, alignment: .trailing),
        ColumnDef("dueDate", weight: 1.5, minWidth: 70),
        ColumnDef("days", weight: 1.0, minWidth: 50, alignment: .trailing),
        ColumnDef("status", weight: 1.5, minWidth: 65),
    ], spacing: 4)

    @State private var invoices: [Invoice] = []
    @State private var filterBucket: String = "All"

    private var filteredInvoices: [Invoice] {
        let calendar = Calendar.current
        let today = Date()
        if filterBucket == "All" { return invoices }
        return invoices.filter { inv in
            let refDate = inv.dueDate ?? inv.invoiceDate
            let days = calendar.dateComponents([.day], from: refDate, to: today).day ?? 0
            switch filterBucket {
            case "Current": return days <= 0
            case "30": return days > 0 && days <= 30
            case "60": return days > 30 && days <= 60
            case "90": return days > 60 && days <= 90
            case "90+": return days > 90
            default: return true
            }
        }
    }

    var body: some View {
        GlassCard(padding: AppSpacing.section) {
            VStack(alignment: .leading, spacing: AppSpacing.section) {
                HStack {
                    SectionHeader(title: "Aging Detail")
                    Spacer()
                    HStack(spacing: AppSpacing.standard) {
                        ForEach(["All", "Current", "30", "60", "90", "90+"], id: \.self) { bucket in
                            FilterPill(title: bucket, isActive: filterBucket == bucket) {
                                filterBucket = bucket
                            }
                        }
                    }
                }

                if filteredInvoices.isEmpty {
                    EmptyStateView(icon: "doc.text", title: "No unpaid invoices", subtitle: "All invoices are paid or no invoices match this filter")
                } else {
                    GeometryReader { geo in
                        let widths = Self.tableLayout.widths(for: geo.size.width - 2 * AppSpacing.standard)
                        VStack(spacing: 0) {
                            // Header
                            HStack(spacing: 4) {
                                TableHeader(title: "Invoice #", width: widths[0])
                                TableHeader(title: "Customer", width: widths[1])
                                TableHeader(title: "Amount", width: widths[2], alignment: .trailing)
                                TableHeader(title: "Paid", width: widths[3], alignment: .trailing)
                                TableHeader(title: "Balance", width: widths[4], alignment: .trailing)
                                TableHeader(title: "Due Date", width: widths[5])
                                TableHeader(title: "Days", width: widths[6], alignment: .trailing)
                                TableHeader(title: "Status", width: widths[7])
                            }
                            .padding(.horizontal, AppSpacing.standard)

                            ScrollView {
                                LazyVStack(spacing: 0) {
                                    ForEach(Array(filteredInvoices.enumerated()), id: \.element.id) { index, inv in
                                        let daysOverdue = daysOver(inv)
                                        let color = agingColor(daysOverdue)

                                        HStack(spacing: 4) {
                                            Text(inv.referenceNumber)
                                                .font(AppTypography.mono)
                                                .foregroundStyle(AppColors.ink)
                                                .frame(width: widths[0], alignment: .leading)

                                            Text(inv.customer?.displayName ?? "—")
                                                .font(AppTypography.body)
                                                .foregroundStyle(AppColors.ink)
                                                .lineLimit(1)
                                                .frame(width: widths[1], alignment: .leading)

                                            Text(inv.grandTotal.asCurrency)
                                                .font(AppTypography.mono)
                                                .foregroundStyle(AppColors.ink)
                                                .frame(width: widths[2], alignment: .trailing)

                                            Text(inv.totalPaid.asCurrency)
                                                .font(AppTypography.mono)
                                                .foregroundStyle(AppColors.inkMuted)
                                                .frame(width: widths[3], alignment: .trailing)

                                            Text(inv.balanceDue.asCurrency)
                                                .font(AppTypography.mono)
                                                .foregroundStyle(color)
                                                .frame(width: widths[4], alignment: .trailing)

                                            Text(inv.dueDate?.formatted(date: .abbreviated, time: .omitted) ?? "—")
                                                .font(AppTypography.mono)
                                                .foregroundStyle(AppColors.inkMuted)
                                                .frame(width: widths[5], alignment: .leading)

                                            Text(daysOverdue > 0 ? "\(daysOverdue)" : "—")
                                                .font(AppTypography.mono)
                                                .foregroundStyle(color)
                                                .frame(width: widths[6], alignment: .trailing)

                                            // Payment progress bar
                                            paymentProgress(inv)
                                                .frame(width: widths[7])
                                        }
                                        .padding(.horizontal, AppSpacing.standard)
                                        .padding(.vertical, AppSpacing.standard)
                                        .staggeredRow(index: index, reduceMotion: reduceMotion)
                                        .accessibilityElement(children: .combine)
                                        .accessibilityLabel("Invoice \(inv.referenceNumber), balance \(inv.balanceDue.asCurrency), \(daysOverdue) days overdue")
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .onAppear { loadInvoices() }
    }

    private func loadInvoices() {
        invoices = ARService.unpaidInvoices(modelContext: modelContext)
            .sorted { daysOver($0) > daysOver($1) }
    }

    private func daysOver(_ inv: Invoice) -> Int {
        let refDate = inv.dueDate ?? inv.invoiceDate
        return Calendar.current.dateComponents([.day], from: refDate, to: Date()).day ?? 0
    }

    private func agingColor(_ days: Int) -> Color {
        switch days {
        case ...0: return AppColors.success
        case 1...30: return AppColors.warning
        case 31...60: return AppColors.warningDeep
        default: return AppColors.danger
        }
    }

    private func paymentProgress(_ inv: Invoice) -> some View {
        let total = NSDecimalNumber(decimal: inv.grandTotal).doubleValue
        let paid = NSDecimalNumber(decimal: inv.totalPaid).doubleValue
        let ratio = total > 0 ? min(paid / total, 1.0) : 0

        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: AppCornerRadius.field, style: .continuous)
                    .fill(AppColors.cardBackground)
                RoundedRectangle(cornerRadius: AppCornerRadius.field, style: .continuous)
                    .fill(ratio >= 1.0 ? AppColors.success : AppColors.primary)
                    .frame(width: geo.size.width * ratio)
            }
        }
        .frame(height: 8)
        .accessibilityLabel("\(Int(ratio * 100))% paid")
    }
}
