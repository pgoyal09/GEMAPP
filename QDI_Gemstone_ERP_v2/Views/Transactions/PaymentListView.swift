import SwiftUI
import SwiftData

/// Inline payment tracking section for InvoiceDocumentView.
struct PaymentListView: View {
    @Bindable var invoice: Invoice
    @Environment(\.modelContext) private var modelContext
    var onDirty: () -> Void

    @State private var showAddPayment = false
    @State private var newAmount: Decimal = 0
    @State private var newMethod: PaymentMethod = .wire
    @State private var newReference: String = ""

    var body: some View {
        GlassCard(padding: AppSpacing.section) {
            VStack(alignment: .leading, spacing: AppSpacing.comfortable) {
                HStack {
                    SectionHeader(title: "Payments")
                    Spacer()
                    Text("Balance: \(invoice.balanceDue.asCurrency)")
                        .font(AppTypography.mono)
                        .foregroundStyle(invoice.balanceDue > 0 ? AppColors.danger : AppColors.success)
                    Button("Add Payment") { showAddPayment = true }
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.primary)
                        .buttonStyle(.plain)
                }

                if invoice.payments.isEmpty {
                    Text("No payments recorded.")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.inkSubtle)
                } else {
                    ForEach(invoice.payments.sorted(by: { $0.date < $1.date })) { payment in
                        HStack(spacing: AppSpacing.section) {
                            Text(payment.date.formatted(date: .abbreviated, time: .omitted))
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.inkSubtle)
                                .frame(width: 80, alignment: .leading)
                            StatusBadge(title: payment.method.rawValue, tone: .neutral)
                            if !payment.referenceNumber.isEmpty {
                                Text(payment.referenceNumber)
                                    .font(AppTypography.mono)
                                    .foregroundStyle(AppColors.inkMuted)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Text(payment.amount.asCurrency)
                                .font(AppTypography.mono)
                                .foregroundStyle(AppColors.success)
                        }
                        .padding(.vertical, 2)
                    }

                    HStack {
                        Spacer()
                        Text("Total Paid: \(invoice.totalPaid.asCurrency)")
                            .font(AppTypography.body.bold())
                            .foregroundStyle(AppColors.ink)
                    }
                }
            }
        }
        .sheet(isPresented: $showAddPayment) {
            addPaymentSheet
        }
    }

    private var addPaymentSheet: some View {
        VStack(spacing: AppSpacing.hero) {
            Text("Record Payment")
                .font(AppTypography.heading)
                .foregroundStyle(AppColors.ink)

            VStack(alignment: .leading, spacing: AppSpacing.comfortable) {
                Text("Amount").font(AppTypography.caption).foregroundStyle(AppColors.inkSubtle)
                TextField("0.00", value: $newAmount, format: .number)
                    .glassField()

                Text("Method").font(AppTypography.caption).foregroundStyle(AppColors.inkSubtle)
                Picker("", selection: $newMethod) {
                    ForEach(PaymentMethod.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .labelsHidden()

                Text("Reference #").font(AppTypography.caption).foregroundStyle(AppColors.inkSubtle)
                TextField("Check #, Wire ref, etc.", text: $newReference)
                    .glassField()
            }

            HStack {
                Button("Cancel") { showAddPayment = false }
                    .buttonStyle(.outline)
                Spacer()
                Button("Save Payment") {
                    let payment = Payment(
                        date: Date(),
                        amount: newAmount,
                        method: newMethod,
                        referenceNumber: newReference,
                        invoice: invoice
                    )
                    modelContext.insert(payment)
                    newAmount = 0
                    newMethod = .wire
                    newReference = ""
                    showAddPayment = false
                    onDirty()
                }.buttonStyle(.gradient)
            }
        }
        .padding(AppSpacing.hero)
        .frame(minWidth: 380)
        .appBackground()
    }
}
