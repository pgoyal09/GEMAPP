import SwiftUI
import SwiftData

struct CustomerDetailView: View {
    let customer: Customer
    @Environment(\.openWindow) private var openWindow
    @Environment(\.modelContext) private var modelContext

    private var fetchedActiveMemos: [Memo] {
        let desc = FetchDescriptor<Memo>(sortBy: [SortDescriptor(\.dateAssigned, order: .reverse)])
        let all = (try? modelContext.fetch(desc)) ?? []
        let customerID = customer.persistentModelID
        return all.filter { $0.status == .onMemo && $0.customer?.persistentModelID == customerID }
    }

    private var fetchedInvoices: [Invoice] {
        let desc = FetchDescriptor<Invoice>(sortBy: [SortDescriptor(\.invoiceDate, order: .reverse)])
        let all = (try? modelContext.fetch(desc)) ?? []
        let customerID = customer.persistentModelID
        return all.filter { $0.customer?.persistentModelID == customerID }
    }

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

                // On Memo
                VStack(alignment: .leading, spacing: 8) {
                    Text("On Memo")
                        .font(.headline)
                    if fetchedActiveMemos.isEmpty {
                        Text("No stones currently on memo")
                            .foregroundStyle(.secondary)
                            .padding()
                    } else {
                        Table(onMemoRows) {
                            TableColumn("Memo #") { row in
                                Button(row.memoRef) { openWindow(id: "memo", value: row.memoID) }
                                    .buttonStyle(.borderless)
                            }
                            .width(80)
                            TableColumn("Stone descriptor") { Text($0.descriptor).lineLimit(2) }
                                .width(min: 200)
                            TableColumn("Transaction date") { Text($0.date, style: .date) }
                                .width(120)
                            TableColumn("Stone value") { Text($0.value, format: .currency(code: "USD")) }
                                .width(100)
                        }
                        .tableStyle(.bordered(alternatesRowBackgrounds: true))
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(8)

                // Past Purchases
                VStack(alignment: .leading, spacing: 8) {
                    Text("Past Purchases")
                        .font(.headline)
                    if pastPurchaseRows.isEmpty {
                        Text("No past purchases")
                            .foregroundStyle(.secondary)
                            .padding()
                    } else {
                        Table(pastPurchaseRows) {
                            TableColumn("Invoice #") { row in
                                Button(row.invoiceRef) { openWindow(id: "invoice", value: row.invoiceID) }
                                    .buttonStyle(.borderless)
                            }
                            .width(80)
                            TableColumn("Stone descriptor") { Text($0.descriptor).lineLimit(2) }
                                .width(min: 200)
                            TableColumn("Transaction date") { Text($0.date, style: .date) }
                                .width(120)
                            TableColumn("Stone value") { Text($0.value, format: .currency(code: "USD")) }
                                .width(100)
                        }
                        .tableStyle(.bordered(alternatesRowBackgrounds: true))
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(8)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minWidth: InspectorWidth.min)
    }

    private var pastPurchases: [Invoice] {
        fetchedInvoices
            .sorted { $0.invoiceDate > $1.invoiceDate }
    }

    private struct OnMemoRow: Identifiable {
        let id: String
        let memoID: PersistentIdentifier
        let memoRef: String
        let descriptor: String
        let date: Date
        let value: Decimal
    }

    private var onMemoRows: [OnMemoRow] {
        fetchedActiveMemos.flatMap { memo in
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

    private var pastPurchaseRows: [PastPurchaseRow] {
        pastPurchases.flatMap { inv in
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
