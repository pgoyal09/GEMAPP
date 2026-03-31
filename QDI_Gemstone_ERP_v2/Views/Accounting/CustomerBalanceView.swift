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
    @State private var showReminderCooldownAlert = false
    @State private var cooldownCustomer: CustomerBalance?
    @State private var cooldownDaysAgo: Int = 0

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
        .alert("Recent Reminder", isPresented: $showReminderCooldownAlert) {
            Button("Send Anyway") {
                if let customer = cooldownCustomer {
                    createAndShareReminder(for: customer)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Last reminder sent \(cooldownDaysAgo) day\(cooldownDaysAgo == 1 ? "" : "s") ago. Send again?")
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

                HStack(spacing: AppSpacing.section) {
                    Button("Record Payment") {
                        showPaymentSheet = true
                    }
                    .buttonStyle(.gradient)
                    .accessibilityLabel("Record payment for \(customer.customerName)")

                    Button("Send Reminder", systemImage: "bell.badge") {
                        sendReminder(for: customer)
                    }
                    .buttonStyle(.outline)
                    .accessibilityLabel("Send payment reminder to \(customer.customerName)")
                }
                .padding(.horizontal, AppSpacing.section)

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
                // Reminder History
                let reminders = fetchReminders(for: customer.customerName)
                if !reminders.isEmpty {
                    SectionHeader(title: "Reminder History")
                        .padding(.horizontal, AppSpacing.section)

                    ScrollView {
                        LazyVStack(spacing: AppSpacing.compact) {
                            ForEach(reminders, id: \.persistentModelID) { reminder in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(reminder.date.formatted(date: .abbreviated, time: .shortened))
                                            .font(AppTypography.caption)
                                            .foregroundStyle(AppColors.inkMuted)
                                        Text("Invoices: \(reminder.invoiceReferences)")
                                            .font(AppTypography.sectionLabel)
                                            .foregroundStyle(AppColors.inkSubtle)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    if reminder.amount > 0 {
                                        Text(reminder.amount.asCurrency)
                                            .font(AppTypography.mono)
                                            .foregroundStyle(AppColors.warning)
                                    }
                                    Image(systemName: reminder.sent ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(reminder.sent ? AppColors.success : AppColors.inkSubtle)
                                }
                                .padding(.horizontal, AppSpacing.section)
                                .padding(.vertical, AppSpacing.compact)
                            }
                        }
                    }
                    .frame(maxHeight: 160)
                }
            } else {
                EmptyStateView(icon: "person.crop.circle", title: "Select a customer", subtitle: "Click a row to see balance details")
            }
        }
        .frame(minWidth: 300, idealWidth: 340, maxWidth: 400)
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

    private func sendReminder(for customer: CustomerBalance) {
        // Check 7-day cooldown
        if !ARService.canSendReminder(customerName: customer.customerName, modelContext: modelContext) {
            // Find how many days ago the last reminder was sent
            let name = customer.customerName
            let descriptor = FetchDescriptor<PaymentReminder>(
                predicate: #Predicate<PaymentReminder> {
                    $0.customerName == name && $0.sent == true
                }
            )
            if let reminders = try? modelContext.fetch(descriptor),
               let latest = reminders.max(by: { $0.date < $1.date }) {
                cooldownDaysAgo = Calendar.current.dateComponents([.day], from: latest.date, to: Date()).day ?? 0
            }
            cooldownCustomer = customer
            showReminderCooldownAlert = true
            return
        }
        createAndShareReminder(for: customer)
    }

    private func createAndShareReminder(for customer: CustomerBalance) {
        let invoiceRefs = customer.invoices.map(\.referenceNumber).joined(separator: ", ")
        let reminder = PaymentReminder(
            customerName: customer.customerName,
            invoiceReferences: invoiceRefs,
            amount: customer.totalOutstanding
        )
        reminder.sent = true
        modelContext.insert(reminder)
        do {
            try modelContext.save()
        } catch {
            toastMessage = "Failed to create reminder"
            toastIsError = true
            return
        }

        // Format reminder text and copy to pasteboard
        let text = formatReminderText(customer: customer)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        toastMessage = "Reminder copied to clipboard for \(customer.customerName)"
        toastIsError = false
    }

    private func formatReminderText(customer: CustomerBalance) -> String {
        let invoiceLines = customer.invoices.map { inv in
            let due = inv.dueDate?.formatted(date: .abbreviated, time: .omitted) ?? "N/A"
            return "  - \(inv.referenceNumber): \(inv.balanceDue.asCurrency) (due \(due))"
        }.joined(separator: "\n")

        return """
        Payment Reminder — Quality Diajewels Inc.

        Dear \(customer.customerName),

        This is a friendly reminder regarding your outstanding balance of \(customer.totalOutstanding.asCurrency).

        Outstanding invoices:
        \(invoiceLines)

        Please arrange payment at your earliest convenience.

        Thank you,
        Quality Diajewels Inc.
        """
    }

    private func fetchReminders(for customerName: String) -> [PaymentReminder] {
        let descriptor = FetchDescriptor<PaymentReminder>(
            predicate: #Predicate<PaymentReminder> { $0.customerName == customerName },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
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
