import SwiftUI
import SwiftData

struct CustomerDetailPanel: View {
    let customer: Customer
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openDocumentTracker) private var openDocTracker
    @State private var showEditSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.hero) {
                headerCard
                customerNotesSection
                CustomerActivityView(customer: customer)
                onMemoSection
                pastPurchasesSection
            }
            .padding(AppSpacing.hero)
        }
        .frame(width: 296)
        .background(AppColors.panelBackground)
        .accessibilityIdentifier("CustomerDetailPanel")
        .overlay(alignment: .leading) {
            Divider().background(AppColors.cardElevated)
        }
        .sheet(isPresented: $showEditSheet) {
            CustomerFormSheet(mode: .edit(customer))
        }
    }

    private var headerCard: some View {
        GlassCard(padding: AppSpacing.section) {
            VStack(alignment: .leading, spacing: AppSpacing.comfortable) {
                HStack {
                    Text(customer.displayName)
                        .font(AppTypography.heading)
                        .foregroundStyle(AppColors.ink)
                    Spacer()
                    Button("Edit") { showEditSheet = true }
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.primary)
                        .buttonStyle(.plain)
                }
                if !customer.company.isEmpty {
                    DetailRow(label: "Company", value: customer.company)
                }
                if !customer.email.isEmpty {
                    DetailRow(label: "Email", value: customer.email)
                }
                if !customer.phone.isEmpty {
                    DetailRow(label: "Phone", value: customer.phone)
                }
                if let addr = customer.formattedAddress {
                    DetailRow(label: "Address", value: addr)
                }
                DetailRow(label: "Exposure", value: customer.openExposure.asCurrency)
            }
        }
    }

    private var customerNotesSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.comfortable) {
            SectionHeader(title: "Notes")
            if customer.notes.isEmpty {
                Text("No notes")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.inkSubtle)
            } else {
                Text(customer.notes)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.inkMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var onMemoSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.comfortable) {
            SectionHeader(title: "On Memo")
                .help("Consignment agreement allowing customer to review stones before buying")
            if customer.activeMemos.isEmpty {
                Text("No active memos")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.inkSubtle)
            } else {
                ForEach(customer.activeMemos) { memo in
                    Button {
                        guard !openDocTracker.isOpen(memoID: memo.persistentModelID) else { return }
                        openWindow(id: "memo", value: memo.persistentModelID)
                    } label: {
                        HStack {
                            Text("#\(memo.referenceNumber)")
                                .font(AppTypography.mono)
                                .foregroundStyle(AppColors.primary)
                            Spacer()
                            Text(memo.openMemoAmount.asCurrency)
                                .font(AppTypography.mono)
                                .foregroundStyle(AppColors.inkMuted)
                        }
                        .padding(.vertical, AppSpacing.compact)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var pastPurchasesSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.comfortable) {
            SectionHeader(title: "Past Purchases")
            let paidInvoices = customer.invoices.filter { $0.status == .paid || $0.status == .sent }
            if paidInvoices.isEmpty {
                Text("No invoices")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.inkSubtle)
            } else {
                ForEach(paidInvoices) { invoice in
                    Button {
                        guard !openDocTracker.isOpen(invoiceID: invoice.persistentModelID) else { return }
                        openWindow(id: "invoice", value: invoice.persistentModelID)
                    } label: {
                        HStack {
                            Text(invoice.referenceNumber)
                                .font(AppTypography.mono)
                                .foregroundStyle(AppColors.primary)
                            Spacer()
                            Text(invoice.totalAmount.asCurrency)
                                .font(AppTypography.mono)
                                .foregroundStyle(AppColors.inkMuted)
                        }
                        .padding(.vertical, AppSpacing.compact)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
