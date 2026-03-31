import Foundation
import SwiftData

// MARK: - AR Data Models

struct ARAgingBucket: Identifiable {
    let id = UUID()
    let label: String
    let daysRange: String
    let invoices: [Invoice]
    var totalAmount: Decimal { invoices.reduce(Decimal.zero) { $0 + $1.balanceDue } }
    var count: Int { invoices.count }
}

struct CustomerBalance: Identifiable {
    let id = UUID()
    let customerName: String
    let customerId: PersistentIdentifier?
    let totalOutstanding: Decimal
    let invoices: [Invoice]
    var overdueCount: Int {
        let today = Date()
        return invoices.filter { inv in
            guard let due = inv.dueDate else { return false }
            return due < today
        }.count
    }
}

// MARK: - AR Service

enum ARService {

    /// Get all unpaid invoices (sent or draft with balance due > 0).
    @MainActor
    static func unpaidInvoices(modelContext: ModelContext) -> [Invoice] {
        let sentStatus = InvoiceStatus.sent
        let draftStatus = InvoiceStatus.draft
        let descriptor = FetchDescriptor<Invoice>(
            predicate: #Predicate<Invoice> {
                $0.status == sentStatus || $0.status == draftStatus
            }
        )
        let invoices = (try? modelContext.fetch(descriptor)) ?? []
        return invoices.filter { $0.balanceDue > 0 }
    }

    /// Group unpaid invoices into aging buckets.
    @MainActor
    static func agingBuckets(modelContext: ModelContext) -> [ARAgingBucket] {
        let invoices = unpaidInvoices(modelContext: modelContext)
        let today = Date()
        let calendar = Calendar.current

        var current: [Invoice] = []
        var d30: [Invoice] = []
        var d60: [Invoice] = []
        var d90plus: [Invoice] = []

        for inv in invoices {
            let refDate = inv.dueDate ?? inv.invoiceDate
            let days = calendar.dateComponents([.day], from: refDate, to: today).day ?? 0
            if days <= 0 {
                current.append(inv)
            } else if days <= 30 {
                d30.append(inv)
            } else if days <= 60 {
                d60.append(inv)
            } else {
                d90plus.append(inv)
            }
        }

        return [
            ARAgingBucket(label: "Current", daysRange: "Not due", invoices: current),
            ARAgingBucket(label: "1-30 Days", daysRange: "1-30", invoices: d30),
            ARAgingBucket(label: "31-60 Days", daysRange: "31-60", invoices: d60),
            ARAgingBucket(label: "90+ Days", daysRange: "90+", invoices: d90plus),
        ]
    }

    /// Group unpaid invoices by customer.
    @MainActor
    static func outstandingByCustomer(modelContext: ModelContext) -> [CustomerBalance] {
        let invoices = unpaidInvoices(modelContext: modelContext)
        var map: [String: (id: PersistentIdentifier?, invoices: [Invoice])] = [:]

        for inv in invoices {
            let name = inv.customer?.displayName ?? "Unknown"
            let custId = inv.customer?.persistentModelID
            var entry = map[name, default: (custId, [])]
            entry.id = custId
            entry.invoices.append(inv)
            map[name] = entry
        }

        return map.map { name, value in
            CustomerBalance(
                customerName: name,
                customerId: value.id,
                totalOutstanding: value.invoices.reduce(Decimal.zero) { $0 + $1.balanceDue },
                invoices: value.invoices
            )
        }.sorted { $0.totalOutstanding > $1.totalOutstanding }
    }

    /// Overdue invoices (past due date).
    @MainActor
    static func overdueInvoices(modelContext: ModelContext) -> [Invoice] {
        let today = Date()
        return unpaidInvoices(modelContext: modelContext).filter { inv in
            guard let due = inv.dueDate else { return false }
            return due < today
        }
    }

    /// Count of invoices overdue by 90+ days (for sidebar badge).
    @MainActor
    static func severeOverdueCount(modelContext: ModelContext) -> Int {
        let today = Date()
        let calendar = Calendar.current
        return unpaidInvoices(modelContext: modelContext).filter { inv in
            let refDate = inv.dueDate ?? inv.invoiceDate
            let days = calendar.dateComponents([.day], from: refDate, to: today).day ?? 0
            return days > 90
        }.count
    }

    /// Record a payment allocated to invoices (oldest first by default).
    @MainActor
    static func recordPayment(
        amount: Decimal,
        method: PaymentMethod,
        reference: String,
        invoices: [Invoice],
        modelContext: ModelContext
    ) throws {
        var remaining = amount
        let sorted = invoices.sorted { ($0.dueDate ?? $0.invoiceDate) < ($1.dueDate ?? $1.invoiceDate) }

        for inv in sorted where remaining > 0 {
            let due = inv.balanceDue
            let allocation = min(remaining, due)
            let payment = Payment(date: Date(), amount: allocation, method: method, referenceNumber: reference)
            payment.invoice = inv
            modelContext.insert(payment)
            remaining -= allocation

            if inv.balanceDue - allocation <= 0 {
                inv.status = .paid
            }
        }

        try modelContext.save()
    }

    /// Check if a reminder was sent to this customer within the last 7 days.
    @MainActor
    static func canSendReminder(customerName: String, modelContext: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<PaymentReminder>(
            predicate: #Predicate<PaymentReminder> {
                $0.customerName == customerName && $0.sent == true
            }
        )
        guard let reminders = try? modelContext.fetch(descriptor) else { return true }
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return !reminders.contains { $0.date > sevenDaysAgo }
    }
}
