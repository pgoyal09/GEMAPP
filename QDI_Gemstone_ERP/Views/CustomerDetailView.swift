import SwiftUI
import SwiftData

struct CustomerDetailView: View {
    let customer: Customer
    @Environment(\.openWindow) private var openWindow
    @Query(sort: \Memo.createdAt, order: .reverse) private var allMemos: [Memo]
    @Query(sort: \Invoice.invoiceDate, order: .reverse) private var allInvoices: [Invoice]

    private var customerMemos: [Memo] {
        allMemos.filter { $0.customer?.persistentModelID == customer.persistentModelID }
    }

    private var customerInvoices: [Invoice] {
        allInvoices.filter { $0.customer?.persistentModelID == customer.persistentModelID }
    }

    private var activeMemosForCustomer: [Memo] {
        customerMemos.filter { !$0.isClosed }
    }

    private var invoicesForCustomer: [Invoice] { customerInvoices }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header info
            VStack(alignment: .leading, spacing: 6) {
                Text(customer.displayName)
                    .font(AppTypography.title)
                    .foregroundStyle(AppColors.ink)
                    .lineLimit(1)
                if let co = customer.company, !co.isEmpty {
                    Text(co)
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.inkMuted)
                        .lineLimit(1)
                }
                if let email = customer.email, !email.isEmpty {
                    Text(email)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.inkMuted)
                        .lineLimit(1)
                }
                if let phone = customer.phone, !phone.isEmpty {
                    Text(phone)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.inkMuted)
                }
                if let addr = customer.formattedAddress {
                    Text(addr)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.inkMuted)
                }
            }
            .padding(AppSpacing.l)

            Divider().background(AppColors.cardStroke)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Preferences section
                    if hasPreferences {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("PREFERENCES")
                                .sectionLabel(tracking: 1)
                                .padding(.horizontal, AppSpacing.l)
                            VStack(alignment: .leading, spacing: AppSpacing.s) {
                                if let shapes = customer.preferredShapes, !shapes.isEmpty {
                                    HStack(alignment: .top, spacing: AppSpacing.m) {
                                        Text("Shapes")
                                            .font(AppTypography.caption)
                                            .foregroundStyle(AppColors.inkSubtle)
                                            .frame(width: 70, alignment: .leading)
                                        Text(shapes)
                                            .font(AppTypography.body)
                                            .foregroundStyle(AppColors.ink)
                                    }
                                }
                                if let colors = customer.preferredColors, !colors.isEmpty {
                                    HStack(alignment: .top, spacing: AppSpacing.m) {
                                        Text("Colors")
                                            .font(AppTypography.caption)
                                            .foregroundStyle(AppColors.inkSubtle)
                                            .frame(width: 70, alignment: .leading)
                                        Text(colors)
                                            .font(AppTypography.body)
                                            .foregroundStyle(AppColors.ink)
                                    }
                                }
                                if let budget = customer.budgetRange, !budget.isEmpty {
                                    HStack(alignment: .top, spacing: AppSpacing.m) {
                                        Text("Budget")
                                            .font(AppTypography.caption)
                                            .foregroundStyle(AppColors.inkSubtle)
                                            .frame(width: 70, alignment: .leading)
                                        Text(budget)
                                            .font(AppTypography.body)
                                            .foregroundStyle(AppColors.ink)
                                    }
                                }
                            }
                            .padding(AppSpacing.m)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppColors.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(AppColors.cardStroke, lineWidth: 1))
                            .padding(.horizontal, AppSpacing.l)
                        }
                    }

                    // On Memo section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ON MEMO (\(onMemoRows(from: activeMemosForCustomer).count))")
                            .sectionLabel(tracking: 1)
                            .padding(.horizontal, AppSpacing.l)

                        if activeMemosForCustomer.isEmpty {
                            Text("No stones currently on memo")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.inkMuted)
                                .padding(.horizontal, AppSpacing.l)
                        } else {
                            VStack(spacing: 0) {
                                // header
                                HStack(spacing: 0) {
                                    Text("MEMO #").frame(width: 70, alignment: .leading).padding(.horizontal, 4)
                                    Text("DESCRIPTION").frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 4)
                                    Text("DATE").frame(width: 80, alignment: .leading).padding(.horizontal, 4)
                                    Text("VALUE").frame(width: 80, alignment: .trailing).padding(.horizontal, 4)
                                }
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(AppColors.inkSubtle)
                                .tracking(0.5)
                                .padding(.horizontal, AppSpacing.l)
                                .padding(.vertical, 5)
                                .background(Color.white.opacity(0.03))
                                ForEach(onMemoRows(from: activeMemosForCustomer)) { row in
                                    HStack(spacing: 0) {
                                        Button(row.memoRef) { openWindow(id: "memo", value: row.memoID) }
                                            .buttonStyle(.borderless)
                                            .foregroundStyle(AppColors.primary)
                                            .font(.system(size: 12, design: .monospaced))
                                            .frame(width: 70, alignment: .leading)
                                            .padding(.horizontal, 4)
                                        Text(row.descriptor)
                                            .font(.system(size: 12))
                                            .foregroundStyle(AppColors.ink)
                                            .lineLimit(2)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.horizontal, 4)
                                        Text(row.date, style: .date)
                                            .font(.system(size: 12))
                                            .foregroundStyle(AppColors.inkMuted)
                                            .frame(width: 80, alignment: .leading)
                                            .padding(.horizontal, 4)
                                        Text(row.value, format: .currency(code: "USD"))
                                            .font(.system(size: 12))
                                            .foregroundStyle(AppColors.ink)
                                            .frame(width: 80, alignment: .trailing)
                                            .padding(.horizontal, 4)
                                    }
                                    .padding(.horizontal, AppSpacing.l)
                                    .padding(.vertical, 7)
                                    Divider().background(Color.white.opacity(0.04))
                                }
                            }
                            .background(AppColors.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(AppColors.cardStroke, lineWidth: 1))
                            .padding(.horizontal, AppSpacing.l)
                        }
                    }

                    // Past Purchases section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PAST PURCHASES (\(pastPurchaseRows(from: invoicesForCustomer).count))")
                            .sectionLabel(tracking: 1)
                            .padding(.horizontal, AppSpacing.l)

                        if invoicesForCustomer.isEmpty {
                            Text("No past purchases")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.inkMuted)
                                .padding(.horizontal, AppSpacing.l)
                        } else {
                            VStack(spacing: 0) {
                                HStack(spacing: 0) {
                                    Text("INV #").frame(width: 70, alignment: .leading).padding(.horizontal, 4)
                                    Text("DESCRIPTION").frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 4)
                                    Text("DATE").frame(width: 80, alignment: .leading).padding(.horizontal, 4)
                                    Text("AMOUNT").frame(width: 80, alignment: .trailing).padding(.horizontal, 4)
                                }
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(AppColors.inkSubtle)
                                .tracking(0.5)
                                .padding(.horizontal, AppSpacing.l)
                                .padding(.vertical, 5)
                                .background(Color.white.opacity(0.03))
                                ForEach(pastPurchaseRows(from: invoicesForCustomer)) { row in
                                    HStack(spacing: 0) {
                                        Button(row.invoiceRef) { openWindow(id: "invoice", value: row.invoiceID) }
                                            .buttonStyle(.borderless)
                                            .foregroundStyle(AppColors.primary)
                                            .font(.system(size: 12, design: .monospaced))
                                            .frame(width: 70, alignment: .leading)
                                            .padding(.horizontal, 4)
                                        Text(row.descriptor)
                                            .font(.system(size: 12))
                                            .foregroundStyle(AppColors.ink)
                                            .lineLimit(2)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.horizontal, 4)
                                        Text(row.date, style: .date)
                                            .font(.system(size: 12))
                                            .foregroundStyle(AppColors.inkMuted)
                                            .frame(width: 80, alignment: .leading)
                                            .padding(.horizontal, 4)
                                        Text(row.value, format: .currency(code: "USD"))
                                            .font(.system(size: 12))
                                            .foregroundStyle(AppColors.ink)
                                            .frame(width: 80, alignment: .trailing)
                                            .padding(.horizontal, 4)
                                    }
                                    .padding(.horizontal, AppSpacing.l)
                                    .padding(.vertical, 7)
                                    Divider().background(Color.white.opacity(0.04))
                                }
                            }
                            .background(AppColors.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(AppColors.cardStroke, lineWidth: 1))
                            .padding(.horizontal, AppSpacing.l)
                        }
                    }
                }
                .padding(.vertical, AppSpacing.l)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppColors.background)
    }


    private var hasPreferences: Bool {
        let shapes = customer.preferredShapes ?? ""
        let colors = customer.preferredColors ?? ""
        let budget = customer.budgetRange ?? ""
        return !shapes.isEmpty || !colors.isEmpty || !budget.isEmpty
    }

    private struct OnMemoRow: Identifiable {
        let id: String
        let memoID: PersistentIdentifier
        let memoRef: String
        let descriptor: String
        let date: Date
        let value: Decimal
    }

    private func onMemoRows(from memos: [Memo]) -> [OnMemoRow] {
        memos.flatMap { memo in
            memo.openLineItems.map { item in
                OnMemoRow(
                    id: "\(memo.id)-\(item.id)",
                    memoID: memo.id,
                    memoRef: memo.referenceNumber ?? "—",
                    descriptor: item.displayName,
                    date: memo.dateAssigned ?? memo.createdAt,
                    value: item.amount
                )
            }
        }
    }

    private struct PastPurchaseRow: Identifiable {
        let id: String
        let invoiceID: PersistentIdentifier
        let invoiceRef: String
        let descriptor: String
        let date: Date
        let value: Decimal
    }

    private func pastPurchaseRows(from invoices: [Invoice]) -> [PastPurchaseRow] {
        invoices.flatMap { inv in
            inv.lineItems.map { item in
                PastPurchaseRow(
                    id: "\(inv.id)-\(item.id)",
                    invoiceID: inv.id,
                    invoiceRef: inv.referenceNumber ?? "—",
                    descriptor: item.displayName,
                    date: inv.invoiceDate,
                    value: item.amount
                )
            }
        }
    }
}

