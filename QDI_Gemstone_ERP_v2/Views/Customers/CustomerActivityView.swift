import SwiftUI
import SwiftData

/// Chronological activity log for a customer (memos, invoices, notes).
struct CustomerActivityView: View {
    let customer: Customer
    @Environment(\.openWindow) private var openWindow

    private var activities: [ActivityItem] {
        var items: [ActivityItem] = []

        for memo in customer.memos {
            items.append(ActivityItem(
                date: memo.createdAt,
                icon: "doc.text",
                iconColor: memoColor(memo.status),
                title: "Memo #\(memo.referenceNumber)",
                subtitle: "\(memo.status.rawValue) — \(memo.lineItems.count) item\(memo.lineItems.count == 1 ? "" : "s")",
                amount: memo.totalAmount,
                windowID: "memo",
                documentID: memo.persistentModelID
            ))
        }

        for invoice in customer.invoices {
            items.append(ActivityItem(
                date: invoice.createdAt,
                icon: "doc.text.fill",
                iconColor: invoiceColor(invoice.status),
                title: "Invoice \(invoice.referenceNumber)",
                subtitle: "\(invoice.status.rawValue) — \(invoice.lineItems.count) item\(invoice.lineItems.count == 1 ? "" : "s")",
                amount: invoice.totalAmount,
                windowID: "invoice",
                documentID: invoice.persistentModelID
            ))
        }

        return items.sorted { $0.date > $1.date }
    }

    // MARK: - Summary Stats

    private var lastMemoDate: Date? {
        customer.memos.compactMap(\.dateAssigned).max()
    }

    private var lastInvoiceDate: Date? {
        customer.invoices.map(\.invoiceDate).max()
    }

    private var outstandingBalance: Decimal {
        customer.invoices
            .filter { $0.status == .sent }
            .reduce(Decimal.zero) { $0 + $1.grandTotal }
    }

    private var totalLifetimeValue: Decimal {
        customer.invoices
            .filter { $0.status == .paid }
            .reduce(Decimal.zero) { $0 + $1.grandTotal }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.comfortable) {
            SectionHeader(title: "Activity Log")

            // Summary stats
            VStack(alignment: .leading, spacing: 4) {
                if let memoDate = lastMemoDate {
                    DetailRow(label: "Last Memo", value: memoDate.formatted(date: .abbreviated, time: .omitted))
                }
                if let invoiceDate = lastInvoiceDate {
                    DetailRow(label: "Last Invoice", value: invoiceDate.formatted(date: .abbreviated, time: .omitted))
                }
                if outstandingBalance > 0 {
                    HStack {
                        Text("Outstanding")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.inkSubtle)
                        Spacer()
                        Text(outstandingBalance.asCurrency)
                            .font(AppTypography.mono)
                            .foregroundStyle(AppColors.danger)
                    }
                }
                if totalLifetimeValue > 0 {
                    HStack {
                        Text("Lifetime Value")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.inkSubtle)
                        Spacer()
                        Text(totalLifetimeValue.asCurrency)
                            .font(AppTypography.mono)
                            .foregroundStyle(AppColors.success)
                    }
                }
            }
            .padding(.bottom, AppSpacing.standard)

            if activities.isEmpty {
                Text("No activity yet")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.inkSubtle)
            } else {
                ForEach(Array(activities.prefix(10).enumerated()), id: \.offset) { _, activity in
                    Button {
                        openWindow(id: activity.windowID, value: activity.documentID)
                    } label: {
                        HStack(spacing: AppSpacing.comfortable) {
                            Image(systemName: activity.icon)
                                .font(.system(size: 14))
                                .foregroundStyle(activity.iconColor)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(activity.title)
                                    .font(AppTypography.body.weight(.medium))
                                    .foregroundStyle(AppColors.ink)
                                Text(activity.subtitle)
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.inkSubtle)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text(activity.amount.asCurrency)
                                    .font(AppTypography.mono)
                                    .foregroundStyle(AppColors.inkMuted)
                                Text(activity.date.formatted(.dateTime.month(.abbreviated).day()))
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.inkSubtle)
                            }
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Helpers

    private func memoColor(_ status: MemoStatus) -> Color {
        switch status {
        case .onMemo: return AppColors.warning
        case .returned: return AppColors.primary
        case .sold: return AppColors.success
        }
    }

    private func invoiceColor(_ status: InvoiceStatus) -> Color {
        switch status {
        case .draft: return AppColors.inkMuted
        case .sent: return AppColors.warning
        case .paid: return AppColors.success
        case .void: return AppColors.danger
        }
    }

    // MARK: - Data

    private struct ActivityItem {
        let date: Date
        let icon: String
        let iconColor: Color
        let title: String
        let subtitle: String
        let amount: Decimal
        let windowID: String
        let documentID: PersistentIdentifier
    }
}
