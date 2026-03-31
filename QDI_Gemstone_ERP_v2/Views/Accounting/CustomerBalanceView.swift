import SwiftUI
import SwiftData

struct CustomerBalanceView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var balances: [CustomerBalance] = []
    @State private var selectedCustomer: CustomerBalance?
    @State private var showPaymentSheet = false
    @State private var paymentAmount = ""
    @State private var paymentMethod: PaymentMethod = .wire
    @State private var paymentReference = ""
    @State private var toastMessage: String?
    @State private var toastIsError = false

    var body: some View {
        HStack(spacing: 0) {
            customerList
            if selectedCustomer != nil {
                Divider().background(AppColors.cardStroke)
                customerDetail
            }
        }
        .onAppear { loadBalances() }
        .overlay {
            if let msg = toastMessage {
                ToastOverlay(message: msg, isError: toastIsError)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation { toastMessage = nil }
                        }
                    }
            }
        }
    }

    private func loadBalances() {
        balances = ARService.outstandingByCustomer(modelContext: modelContext)
    }

    // MARK: - Customer List

    private var customerList: some View {
        GlassCard(padding: AppSpacing.section) {
            VStack(alignment: .leading, spacing: AppSpacing.section) {
                SectionHeader(title: "Customer Balances")

                if balances.isEmpty {
                    EmptyStateView(icon: "person.2", title: "No outstanding balances")
                } else {
                    HStack(spacing: 0) {
                        TableHeader(title: "Customer", width: TableColumn.customer)
                        TableHeader(title: "Outstanding", width: TableColumn.price, alignment: .trailing)
                        TableHeader(title: "Invoices", width: TableColumn.quantity, alignment: .trailing)
                        TableHeader(title: "Overdue", width: TableColumn.quantity, alignment: .trailing)
                    }
                    .padding(.horizontal, AppSpacing.comfortable)

                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(balances.enumerated()), id: \.element.id) { index, balance in
                                HoverRow(isSelected: selectedCustomer?.id == balance.id) {
                                    selectedCustomer = balance
                                } content: {
                                    HStack(spacing: 0) {
                                        Text(balance.customerName)
                                            .font(AppTypography.body)
                                            .foregroundStyle(AppColors.ink)
                                            .lineLimit(1)
                                            .frame(width: TableColumn.customer, alignment: .leading)

                                        Text(balance.totalOutstanding.asCurrency)
                                            .font(AppTypography.mono)
                                            .foregroundStyle(AppColors.warning)
                                            .frame(width: TableColumn.price, alignment: .trailing)

                                        Text("\(balance.invoices.count)")
                                            .font(AppTypography.mono)
                                            .foregroundStyle(AppColors.ink)
                                            .frame(width: TableColumn.quantity, alignment: .trailing)

                                        Text("\(balance.overdueCount)")
                                            .font(AppTypography.mono)
                                            .foregroundStyle(balance.overdueCount > 0 ? AppColors.danger : AppColors.inkSubtle)
                                            .frame(width: TableColumn.quantity, alignment: .trailing)
                                    }
                                }
                                .staggeredRow(index: index, reduceMotion: reduceMotion)
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("\(balance.customerName): \(balance.totalOutstanding.asCurrency) outstanding, \(balance.overdueCount) overdue")
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
            if let customer = selectedCustomer {
                GlassCard(padding: AppSpacing.hero) {
                    VStack(alignment: .leading, spacing: AppSpacing.standard) {
                        Text(customer.customerName)
                            .font(AppTypography.heading)
                            .foregroundStyle(AppColors.ink)
                        HStack(spacing: AppSpacing.section) {
                            VStack(alignment: .leading) {
                                Text("OUTSTANDING")
                                    .font(AppTypography.sectionLabel)
                                    .foregroundStyle(AppColors.inkSubtle)
                                Text(customer.totalOutstanding.asCurrency)
                                    .font(AppTypography.largeValue)
                                    .foregroundStyle(AppColors.warning)
                            }
                            VStack(alignment: .leading) {
                                Text("OVERDUE")
                                    .font(AppTypography.sectionLabel)
                                    .foregroundStyle(AppColors.inkSubtle)
                                Text("\(customer.overdueCount)")
                                    .font(AppTypography.largeValue)
                                    .foregroundStyle(customer.overdueCount > 0 ? AppColors.danger : AppColors.success)
                            }
                        }
                    }
                }

                Button("Record Payment") {
                    showPaymentSheet = true
                }
                .buttonStyle(.gradient)
                .padding(.horizontal, AppSpacing.section)
                .accessibilityLabel("Record payment for \(customer.customerName)")

                SectionHeader(title: "Unpaid Invoices")
                    .padding(.horizontal, AppSpacing.section)

                ScrollView {
                    LazyVStack(spacing: AppSpacing.standard) {
                        ForEach(customer.invoices.sorted(by: { ($0.dueDate ?? $0.invoiceDate) < ($1.dueDate ?? $1.invoiceDate) })) { inv in
                            GlassCard(padding: AppSpacing.comfortable) {
                                VStack(alignment: .leading, spacing: AppSpacing.compact) {
                                    HStack {
                                        Text(inv.referenceNumber)
                                            .font(AppTypography.mono)
                                            .foregroundStyle(AppColors.ink)
                                        Spacer()
                                        Text(inv.balanceDue.asCurrency)
                                            .font(AppTypography.body)
                                            .foregroundStyle(AppColors.warning)
                                    }
                                    HStack {
                                        Text("Due: \(inv.dueDate?.formatted(date: .abbreviated, time: .omitted) ?? "N/A")")
                                            .font(AppTypography.caption)
                                            .foregroundStyle(AppColors.inkSubtle)
                                        Spacer()
                                        Text("Total: \(inv.grandTotal.asCurrency)")
                                            .font(AppTypography.caption)
                                            .foregroundStyle(AppColors.inkSubtle)
                                    }

                                    // Payment progress
                                    let total = NSDecimalNumber(decimal: inv.grandTotal).doubleValue
                                    let paid = NSDecimalNumber(decimal: inv.totalPaid).doubleValue
                                    let ratio = total > 0 ? min(paid / total, 1.0) : 0

                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                                .fill(AppColors.cardBackground)
                                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                                .fill(AppColors.primary)
                                                .frame(width: geo.size.width * ratio)
                                        }
                                    }
                                    .frame(height: 6)

                                    if inv.totalPaid > 0 {
                                        Text("Paid: \(inv.totalPaid.asCurrency) (\(Int(ratio * 100))%)")
                                            .font(AppTypography.sectionLabel)
                                            .foregroundStyle(AppColors.inkMuted)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.section)
                }

                // Payment History
                let allPayments = customer.invoices.flatMap(\.payments).sorted { $0.date > $1.date }
                if !allPayments.isEmpty {
                    SectionHeader(title: "Payment History")
                        .padding(.horizontal, AppSpacing.section)

                    ScrollView {
                        LazyVStack(spacing: AppSpacing.compact) {
                            ForEach(allPayments, id: \.persistentModelID) { payment in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(payment.date.formatted(date: .abbreviated, time: .omitted))
                                            .font(AppTypography.caption)
                                            .foregroundStyle(AppColors.inkMuted)
                                        Text(payment.method.rawValue.capitalized)
                                            .font(AppTypography.sectionLabel)
                                            .foregroundStyle(AppColors.inkSubtle)
                                    }
                                    Spacer()
                                    Text(payment.amount.asCurrency)
                                        .font(AppTypography.mono)
                                        .foregroundStyle(AppColors.success)
                                }
                                .padding(.horizontal, AppSpacing.section)
                                .padding(.vertical, AppSpacing.compact)
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                }
            } else {
                EmptyStateView(icon: "person.crop.circle", title: "Select a customer", subtitle: "Click a row to see balance details")
            }
        }
        .frame(width: 340)
        .sheet(isPresented: $showPaymentSheet) {
            paymentSheet
        }
    }

    // MARK: - Payment Sheet

    private var paymentSheet: some View {
        VStack(spacing: AppSpacing.hero) {
            Text("Record Payment")
                .font(AppTypography.heading)
                .foregroundStyle(AppColors.ink)

            FormField(label: "Amount", text: $paymentAmount)
                .accessibilityLabel("Payment amount")

            FormPicker(label: "Method", selection: $paymentMethod) {
                ForEach(PaymentMethod.allCases, id: \.self) { method in
                    Text(method.rawValue.capitalized).tag(method)
                }
            }

            FormField(label: "Reference #", text: $paymentReference)
                .accessibilityLabel("Payment reference number")

            HStack(spacing: AppSpacing.section) {
                Button("Cancel") { showPaymentSheet = false }
                    .buttonStyle(.outline)
                Button("Record") { recordPayment() }
                    .buttonStyle(.gradient)
                    .disabled(paymentAmount.isEmpty)
            }
        }
        .padding(AppSpacing.hero)
        .frame(width: 400)
        .appBackground()
    }

    private func recordPayment() {
        guard let customer = selectedCustomer,
              let amount = Decimal(string: paymentAmount), amount > 0 else {
            toastMessage = "Invalid amount"
            toastIsError = true
            return
        }
        do {
            try ARService.recordPayment(
                amount: amount,
                method: paymentMethod,
                reference: paymentReference,
                invoices: customer.invoices,
                modelContext: modelContext
            )
            showPaymentSheet = false
            paymentAmount = ""
            paymentReference = ""
            toastMessage = "Payment of \(amount.asCurrency) recorded"
            toastIsError = false
            loadBalances()
            // Refresh selected customer
            selectedCustomer = balances.first { $0.customerName == customer.customerName }
        } catch {
            toastMessage = "Failed to record payment"
            toastIsError = true
        }
    }
}
