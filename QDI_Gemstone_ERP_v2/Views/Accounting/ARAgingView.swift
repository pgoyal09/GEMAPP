import SwiftUI
import SwiftData

struct ARAgingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                    // Header
                    HStack(spacing: 4) {
                        TableHeader(title: "Invoice #", width: TableColumn.invoice)
                        TableHeader(title: "Customer", width: TableColumn.customer)
                        TableHeader(title: "Amount", width: TableColumn.price, alignment: .trailing)
                        TableHeader(title: "Paid", width: TableColumn.price, alignment: .trailing)
                        TableHeader(title: "Balance", width: TableColumn.price, alignment: .trailing)
                        TableHeader(title: "Due Date", width: TableColumn.date)
                        TableHeader(title: "Days", width: TableColumn.days, alignment: .trailing)
                        TableHeader(title: "Status", width: TableColumn.status)
                    }
                    .padding(.horizontal, AppSpacing.comfortable)

                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(filteredInvoices.enumerated()), id: \.element.id) { index, inv in
                                let daysOverdue = daysOver(inv)
                                let color = agingColor(daysOverdue)

                                HStack(spacing: 4) {
                                    Text(inv.referenceNumber)
                                        .font(AppTypography.mono)
                                        .foregroundStyle(AppColors.ink)
                                        .frame(minWidth: TableColumn.invoice, maxWidth: .infinity, alignment: .leading)

                                    Text(inv.customer?.displayName ?? "—")
                                        .font(AppTypography.body)
                                        .foregroundStyle(AppColors.ink)
                                        .lineLimit(1)
                                        .frame(minWidth: TableColumn.customer, maxWidth: .infinity, alignment: .leading)

                                    Text(inv.grandTotal.asCurrency)
                                        .font(AppTypography.mono)
                                        .foregroundStyle(AppColors.ink)
                                        .frame(minWidth: TableColumn.price, maxWidth: .infinity, alignment: .trailing)

                                    Text(inv.totalPaid.asCurrency)
                                        .font(AppTypography.mono)
                                        .foregroundStyle(AppColors.inkMuted)
                                        .frame(minWidth: TableColumn.price, maxWidth: .infinity, alignment: .trailing)

                                    Text(inv.balanceDue.asCurrency)
                                        .font(AppTypography.mono)
                                        .foregroundStyle(color)
                                        .frame(minWidth: TableColumn.price, maxWidth: .infinity, alignment: .trailing)

                                    Text(inv.dueDate?.formatted(date: .abbreviated, time: .omitted) ?? "—")
                                        .font(AppTypography.mono)
                                        .foregroundStyle(AppColors.inkMuted)
                                        .frame(minWidth: TableColumn.date, maxWidth: .infinity, alignment: .leading)

                                    Text(daysOverdue > 0 ? "\(daysOverdue)" : "—")
                                        .font(AppTypography.mono)
                                        .foregroundStyle(color)
                                        .frame(minWidth: TableColumn.days, maxWidth: .infinity, alignment: .trailing)

                                    // Payment progress bar
                                    paymentProgress(inv)
                                        .frame(minWidth: TableColumn.status, maxWidth: .infinity)
                                }
                                .padding(.horizontal, AppSpacing.comfortable)
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
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(AppColors.cardBackground)
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(ratio >= 1.0 ? AppColors.success : AppColors.primary)
                    .frame(width: geo.size.width * ratio)
            }
        }
        .frame(height: 8)
        .accessibilityLabel("\(Int(ratio * 100))% paid")
    }
}
