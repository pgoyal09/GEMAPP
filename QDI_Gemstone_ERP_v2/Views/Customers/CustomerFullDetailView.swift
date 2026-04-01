import SwiftUI
import SwiftData

/// Full-screen detail sheet shown on double-clicking a customer row.
/// Shows customer info bar at top plus a table of all sold line items.
struct CustomerFullDetailView: View {
    let customer: Customer
    @Environment(\.dismiss) private var dismiss

    private struct SoldEntry: Identifiable {
        let id = UUID()
        let lineItem: LineItem
        let ref: String
        let refDate: Date
    }

    private var soldLineItems: [SoldEntry] {
        var results: [SoldEntry] = []

        for memo in customer.memos {
            for item in memo.lineItems where item.status == .sold {
                results.append(SoldEntry(lineItem: item, ref: "M-\(memo.referenceNumber)", refDate: item.soldDate ?? memo.createdAt))
            }
        }

        for invoice in customer.invoices {
            for item in invoice.lineItems {
                if item.originLineItem != nil { continue }
                results.append(SoldEntry(lineItem: item, ref: "INV-\(invoice.referenceNumber)", refDate: item.soldDate ?? invoice.invoiceDate))
            }
        }

        return results.sorted { $0.refDate > $1.refDate }
    }

    private var totalBusiness: Decimal {
        soldLineItems.reduce(Decimal.zero) { $0 + $1.lineItem.netAmount }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            headerBar

            Divider().background(AppColors.cardStroke)

            // Info strip
            infoStrip

            Divider().background(AppColors.cardStroke)

            // Line items table
            lineItemsTable
        }
        .frame(minWidth: 800, minHeight: 500)
        .appBackground()
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(customer.displayName)
                    .font(AppTypography.heading)
                    .foregroundStyle(AppColors.ink)
                if !customer.company.isEmpty {
                    Text(customer.company)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.inkSubtle)
                }
            }
            Spacer()
            Button("Done") { dismiss() }
                .buttonStyle(.outline)
        }
        .padding(.horizontal, AppSpacing.hero)
        .padding(.vertical, AppSpacing.section)
    }

    // MARK: - Info Strip

    private var infoStrip: some View {
        HStack(spacing: AppSpacing.hero) {
            infoItem(icon: "phone", label: "Phone", value: customer.phone.isEmpty ? "—" : customer.phone)
            infoItem(icon: "envelope", label: "Email", value: customer.email.isEmpty ? "—" : customer.email)
            infoItem(icon: "dollarsign.circle", label: "Total Business", value: totalBusiness.asCurrency)
            infoItem(icon: "doc.text", label: "Open Memos", value: "\(customer.activeMemos.count)")
            Spacer()
        }
        .padding(.horizontal, AppSpacing.hero)
        .padding(.vertical, AppSpacing.comfortable)
        .background(AppColors.cardBackground)
    }

    private func infoItem(icon: String, label: String, value: String) -> some View {
        HStack(spacing: AppSpacing.standard) {
            Image(systemName: icon)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.primary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(label.uppercased())
                    .font(AppTypography.sectionLabel)
                    .foregroundStyle(AppColors.inkSubtle)
                    .tracking(0.5)
                Text(value)
                    .font(AppTypography.body.weight(.medium))
                    .foregroundStyle(AppColors.ink)
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Line Items Table

    private var lineItemsTable: some View {
        VStack(spacing: 0) {
            // Table header
            HStack(spacing: 4) {
                Text("Date")
                    .frame(width: TableColumn.date, alignment: .leading)
                Text("Item Description")
                    .frame(width: TableColumn.description + 40, alignment: .leading)
                Text("Carat")
                    .frame(width: TableColumn.carat, alignment: .trailing)
                Text("Amount")
                    .frame(width: TableColumn.price, alignment: .trailing)
                Text("Memo / Invoice #")
                    .frame(width: TableColumn.memo + 30, alignment: .leading)
                Spacer()
            }
            .font(AppTypography.sectionLabel)
            .foregroundStyle(AppColors.inkSubtle)
            .padding(.horizontal, AppSpacing.section)
            .padding(.vertical, AppSpacing.comfortable)

            Divider().background(AppColors.cardStroke)

            if soldLineItems.isEmpty {
                EmptyStateView(icon: "cart", title: "No sold items", subtitle: "Sold items for this customer will appear here")
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(soldLineItems) { entry in
                            HStack(spacing: 4) {
                                Text(entry.refDate.formatted(.dateTime.month(.abbreviated).day().year()))
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.inkMuted)
                                    .frame(width: TableColumn.date, alignment: .leading)

                                Text(entry.lineItem.displayName)
                                    .font(AppTypography.body)
                                    .foregroundStyle(AppColors.ink)
                                    .lineLimit(1)
                                    .frame(width: TableColumn.description + 40, alignment: .leading)

                                Text(entry.lineItem.displayCarats)
                                    .font(AppTypography.mono)
                                    .foregroundStyle(AppColors.ink)
                                    .frame(width: TableColumn.carat, alignment: .trailing)

                                Text(entry.lineItem.netAmount.asCurrency)
                                    .font(AppTypography.mono)
                                    .foregroundStyle(AppColors.ink)
                                    .frame(width: TableColumn.price, alignment: .trailing)

                                Text(entry.ref)
                                    .font(AppTypography.mono)
                                    .foregroundStyle(AppColors.primary)
                                    .lineLimit(1)
                                    .frame(width: TableColumn.memo + 30, alignment: .leading)

                                Spacer()
                            }
                            .padding(.horizontal, AppSpacing.section)
                            .padding(.vertical, AppSpacing.comfortable)
                        }
                    }
                    .padding(.vertical, AppSpacing.standard)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .glassTable()
        .padding(.horizontal, AppSpacing.hero)
        .padding(.bottom, AppSpacing.hero)
        .padding(.top, AppSpacing.comfortable)
    }
}
