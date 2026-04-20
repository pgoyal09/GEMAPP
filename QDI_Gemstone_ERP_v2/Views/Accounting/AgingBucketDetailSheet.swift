import SwiftUI
import SwiftData

/// Detail sheet showing invoices in a specific aging bucket.
struct AgingBucketDetailSheet: View {
    let bucketID: String
    let invoices: [Invoice]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openDocumentTracker) private var openDocTracker

    private var bucketLabel: String {
        switch bucketID {
        case "0-30": return "0–30 Days"
        case "31-60": return "31–60 Days"
        case "61-90": return "61–90 Days"
        case "90+": return "90+ Days"
        default: return bucketID
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.hero) {
            HStack {
                Text("Aged Receivables — \(bucketLabel)")
                    .font(AppTypography.heading)
                    .foregroundStyle(AppColors.ink)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.outline)
            }

            if invoices.isEmpty {
                EmptyStateView(icon: "doc.text", title: "No invoices in this range")
            } else {
                ScrollView {
                    LazyVStack(spacing: AppSpacing.standard) {
                        ForEach(invoices) { invoice in
                            Button {
                                guard !openDocTracker.isOpen(invoiceID: invoice.persistentModelID) else { return }
                                openWindow(id: "invoice", value: invoice.persistentModelID)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Invoice \(invoice.referenceNumber)")
                                            .font(AppTypography.body.weight(.medium))
                                            .foregroundStyle(AppColors.ink)
                                        Text(invoice.customer?.displayName ?? "No customer")
                                            .font(AppTypography.caption)
                                            .foregroundStyle(AppColors.inkSubtle)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(invoice.totalAmount.asCurrency)
                                            .font(AppTypography.mono)
                                            .foregroundStyle(AppColors.ink)
                                        Text(invoice.invoiceDate.formatted(.dateTime.month(.abbreviated).day().year()))
                                            .font(AppTypography.caption)
                                            .foregroundStyle(AppColors.inkSubtle)
                                    }
                                }
                                .padding(AppSpacing.section)
                                .background(
                                    RoundedRectangle(cornerRadius: AppCornerRadius.medium, style: .continuous)
                                        .fill(AppColors.softHighlight)
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                HStack {
                    Text("\(invoices.count) invoice\(invoices.count == 1 ? "" : "s")")
                        .font(AppTypography.caption.bold())
                        .foregroundStyle(AppColors.ink)
                    Spacer()
                    Text("Total: \(invoices.reduce(Decimal.zero) { $0 + $1.totalAmount }.asCurrency)")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.inkMuted)
                }
            }
        }
        .padding(AppSpacing.hero)
        .frame(minWidth: 500, minHeight: 400)
        .appBackground()
    }
}
