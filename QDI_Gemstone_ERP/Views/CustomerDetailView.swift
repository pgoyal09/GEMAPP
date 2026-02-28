import SwiftUI
import SwiftData

struct CustomerDetailView: View {
    let customer: Customer

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(customer.displayName)
                    .font(.title)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if let email = customer.email {
                    Text(email)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                // Currently on Memo
                VStack(alignment: .leading, spacing: 12) {
                    Text("Currently on Memo")
                        .font(.headline)

                    if customer.activeMemos.isEmpty {
                        Text("No stones currently on memo")
                            .foregroundStyle(.secondary)
                            .padding()
                    } else {
                        ForEach(customer.activeMemos, id: \.id) { memo in
                            MemoCard(memo: memo)
                        }
                    }
                }

                // Past Purchases (Invoices for this customer)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Past Purchases")
                        .font(.headline)

                    if pastPurchases.isEmpty {
                        Text("No past purchases")
                            .foregroundStyle(.secondary)
                            .padding()
                    } else {
                        ForEach(pastPurchases, id: \.id) { invoice in
                            InvoiceCard(invoice: invoice)
                        }
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minWidth: InspectorWidth.min)
    }

    private var pastPurchases: [Invoice] {
        (customer.invoices ?? [])
            .sorted { $0.invoiceDate > $1.invoiceDate }
    }
}

struct InvoiceCard: View {
    let invoice: Invoice

    private var total: Decimal {
        invoice.lineItems.reduce(Decimal(0)) { $0 + $1.amount }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(invoice.referenceNumber != nil ? "Invoice #\(invoice.referenceNumber!)" : "Invoice")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
                Text(invoice.effectiveStatus.rawValue)
                    .font(.caption)
                    .foregroundStyle(invoice.effectiveStatus == .paid ? Color.green : Color.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            HStack {
                Text(invoice.invoiceDate, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(total, format: .currency(code: "USD"))
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct MemoCard: View {
    let memo: Memo

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(memo.status.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
                if let date = memo.dateAssigned {
                    Text(date, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text(memo.lineItems.map { $0.displayName }.joined(separator: ", "))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .truncationMode(.tail)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
}
