import SwiftUI
import SwiftData

/// Overlay detail panel shown on double-clicking a customer row.
/// Shows customer info bar at top plus tabbed view: Memos | Invoices | Sold Items.
struct CustomerFullDetailView: View {
    let customer: Customer
    var onDismiss: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: DetailTab = .memos

    private enum DetailTab: String, CaseIterable {
        case memos = "Memos"
        case invoices = "Invoices"
        case soldItems = "Sold Items"
    }

    // MARK: - Sold entries

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

    var body: some View {
        VStack(spacing: 0) {
            // Top info bar
            customerInfoBar

            Divider().background(AppColors.cardStroke)

            // Tab picker
            tabBar

            Divider().background(AppColors.cardStroke)

            // Tab content
            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Info Bar

    private var customerInfoBar: some View {
        VStack(alignment: .leading, spacing: AppSpacing.standard) {
            HStack {
                Text(customer.displayName)
                    .font(AppTypography.heading)
                    .foregroundStyle(AppColors.ink)
                Spacer()
                Button { dismissPanel() } label: {
                    Image(systemName: "xmark")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.inkSubtle)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: AppSpacing.section) {
                if !customer.company.isEmpty {
                    infoChip(icon: "building.2", text: customer.company)
                }
                if !customer.email.isEmpty {
                    infoChip(icon: "envelope", text: customer.email)
                }
                if !customer.phone.isEmpty {
                    infoChip(icon: "phone", text: customer.phone)
                }
            }
        }
        .padding(.horizontal, AppSpacing.section)
        .padding(.vertical, AppSpacing.comfortable)
        .background(AppColors.cardBackground)
    }

    private func infoChip(icon: String, text: String) -> some View {
        HStack(spacing: AppSpacing.compact) {
            Image(systemName: icon)
                .font(AppTypography.sectionLabel)
                .foregroundStyle(AppColors.primary)
            Text(text)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.inkMuted)
                .lineLimit(1)
        }
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: AppSpacing.standard) {
            ForEach(DetailTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Text(tab.rawValue)
                        .font(AppTypography.caption.weight(selectedTab == tab ? .semibold : .regular))
                        .foregroundStyle(selectedTab == tab ? AppColors.primary : AppColors.inkSubtle)
                        .padding(.horizontal, AppSpacing.comfortable)
                        .padding(.vertical, AppSpacing.standard)
                        .background(
                            selectedTab == tab
                                ? AppColors.primary.opacity(0.12)
                                : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, AppSpacing.section)
        .padding(.vertical, AppSpacing.standard)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .memos:
            memosTab
        case .invoices:
            invoicesTab
        case .soldItems:
            soldItemsTab
        }
    }

    // MARK: - Memos Tab

    private var memosTab: some View {
        VStack(spacing: 0) {
            HStack(spacing: AppSpacing.tableColumnGap) {
                Text("Ref #").frame(width: 70, alignment: .leading)
                Text("Status").frame(width: 70, alignment: .leading)
                Text("Items").frame(width: 50, alignment: .trailing)
                Text("Amount").frame(width: 80, alignment: .trailing)
                Text("Date").frame(width: 80, alignment: .leading)
                Spacer()
            }
            .font(AppTypography.sectionLabel)
            .foregroundStyle(AppColors.inkSubtle)
            .padding(.horizontal, AppSpacing.section)
            .padding(.vertical, AppSpacing.standard)

            Divider().background(AppColors.cardStroke)

            if customer.memos.isEmpty {
                EmptyStateView(icon: "doc.text", title: "No memos")
                    .frame(maxWidth: .infinity)
                    .frame(height: 150)
            } else {
                ScrollView {
                    LazyVStack(spacing: AppSpacing.tight) {
                        ForEach(customer.memos.sorted(by: { $0.createdAt > $1.createdAt })) { memo in
                            HStack(spacing: AppSpacing.tableColumnGap) {
                                Text("#\(memo.referenceNumber)")
                                    .font(AppTypography.mono)
                                    .foregroundStyle(AppColors.primary)
                                    .lineLimit(1)
                                    .frame(width: 70, alignment: .leading)

                                StatusBadge(
                                    title: memo.status.rawValue,
                                    tone: memoTone(memo.status)
                                )
                                .frame(width: 70, alignment: .leading)

                                Text("\(memo.lineItems.count)")
                                    .font(AppTypography.mono)
                                    .foregroundStyle(AppColors.inkMuted)
                                    .frame(width: 50, alignment: .trailing)

                                Text(memo.totalAmount.asCurrency)
                                    .font(AppTypography.mono)
                                    .foregroundStyle(AppColors.ink)
                                    .frame(width: 80, alignment: .trailing)

                                Text(memo.createdAt.formatted(.dateTime.month(.abbreviated).day()))
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.inkMuted)
                                    .frame(width: 80, alignment: .leading)

                                Spacer()
                            }
                            .padding(.horizontal, AppSpacing.section)
                            .padding(.vertical, AppSpacing.standard)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Invoices Tab

    private var invoicesTab: some View {
        VStack(spacing: 0) {
            HStack(spacing: AppSpacing.tableColumnGap) {
                Text("Ref #").frame(width: 80, alignment: .leading)
                Text("Status").frame(width: 70, alignment: .leading)
                Text("Total").frame(width: 80, alignment: .trailing)
                Text("Date").frame(width: 80, alignment: .leading)
                Spacer()
            }
            .font(AppTypography.sectionLabel)
            .foregroundStyle(AppColors.inkSubtle)
            .padding(.horizontal, AppSpacing.section)
            .padding(.vertical, AppSpacing.standard)

            Divider().background(AppColors.cardStroke)

            if customer.invoices.isEmpty {
                EmptyStateView(icon: "doc.plaintext", title: "No invoices")
                    .frame(maxWidth: .infinity)
                    .frame(height: 150)
            } else {
                ScrollView {
                    LazyVStack(spacing: AppSpacing.tight) {
                        ForEach(customer.invoices.sorted(by: { $0.invoiceDate > $1.invoiceDate })) { invoice in
                            HStack(spacing: AppSpacing.tableColumnGap) {
                                Text(invoice.referenceNumber)
                                    .font(AppTypography.mono)
                                    .foregroundStyle(AppColors.primary)
                                    .lineLimit(1)
                                    .frame(width: 80, alignment: .leading)

                                StatusBadge(
                                    title: invoice.status.rawValue,
                                    tone: invoiceTone(invoice.status)
                                )
                                .frame(width: 70, alignment: .leading)

                                Text(invoice.totalAmount.asCurrency)
                                    .font(AppTypography.mono)
                                    .foregroundStyle(AppColors.ink)
                                    .frame(width: 80, alignment: .trailing)

                                Text(invoice.invoiceDate.formatted(.dateTime.month(.abbreviated).day()))
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.inkMuted)
                                    .frame(width: 80, alignment: .leading)

                                Spacer()
                            }
                            .padding(.horizontal, AppSpacing.section)
                            .padding(.vertical, AppSpacing.standard)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Sold Items Tab

    private var soldItemsTab: some View {
        VStack(spacing: 0) {
            HStack(spacing: AppSpacing.tableColumnGap) {
                Text("Date").frame(width: 70, alignment: .leading)
                Text("Item").frame(width: 120, alignment: .leading)
                Text("Ct").frame(width: 50, alignment: .trailing)
                Text("Amount").frame(width: 80, alignment: .trailing)
                Text("Ref").frame(width: 60, alignment: .leading)
                Spacer()
            }
            .font(AppTypography.sectionLabel)
            .foregroundStyle(AppColors.inkSubtle)
            .padding(.horizontal, AppSpacing.section)
            .padding(.vertical, AppSpacing.standard)

            Divider().background(AppColors.cardStroke)

            if soldLineItems.isEmpty {
                EmptyStateView(icon: "cart", title: "No sold items")
                    .frame(maxWidth: .infinity)
                    .frame(height: 150)
            } else {
                ScrollView {
                    LazyVStack(spacing: AppSpacing.tight) {
                        ForEach(soldLineItems) { entry in
                            HStack(spacing: AppSpacing.tableColumnGap) {
                                Text(entry.refDate.formatted(.dateTime.month(.abbreviated).day()))
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.inkMuted)
                                    .frame(width: 70, alignment: .leading)

                                Text(entry.lineItem.displayName)
                                    .font(AppTypography.body)
                                    .foregroundStyle(AppColors.ink)
                                    .lineLimit(1)
                                    .frame(width: 120, alignment: .leading)

                                Text(entry.lineItem.displayCarats)
                                    .font(AppTypography.mono)
                                    .foregroundStyle(AppColors.ink)
                                    .frame(width: 50, alignment: .trailing)

                                Text(entry.lineItem.netAmount.asCurrency)
                                    .font(AppTypography.mono)
                                    .foregroundStyle(AppColors.ink)
                                    .frame(width: 80, alignment: .trailing)

                                Text(entry.ref)
                                    .font(AppTypography.mono)
                                    .foregroundStyle(AppColors.primary)
                                    .lineLimit(1)
                                    .frame(width: 60, alignment: .leading)

                                Spacer()
                            }
                            .padding(.horizontal, AppSpacing.section)
                            .padding(.vertical, AppSpacing.standard)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func dismissPanel() {
        if let onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }

    private func memoTone(_ status: MemoStatus) -> StatusBadge.Tone {
        switch status {
        case .onMemo: return .warning
        case .returned: return .neutral
        case .sold: return .success
        }
    }

    private func invoiceTone(_ status: InvoiceStatus) -> StatusBadge.Tone {
        switch status {
        case .draft: return .neutral
        case .sent: return .warning
        case .paid: return .success
        case .void: return .danger
        }
    }
}
