import SwiftUI
import SwiftData

/// Document window for an Invoice. Fetches by PersistentIdentifier; shows ContentUnavailableView if not found.
struct InvoiceWindowView: View {
    let invoiceID: PersistentIdentifier
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            if let invoice = fetchInvoice() {
                InvoiceDetailView(invoice: invoice) {
                    // onUpdate - list will refresh when user returns to Invoices
                }
            } else {
                ContentUnavailableView(
                    "Invoice Not Found",
                    systemImage: "dollarsign.circle",
                    description: Text("This invoice may have been deleted.")
                )
            }
        }
        .frame(minWidth: 1100, minHeight: 760)
    }

    private func fetchInvoice() -> Invoice? {
        var descriptor = FetchDescriptor<Invoice>(predicate: #Predicate<Invoice> { invoice in
            invoice.persistentModelID == invoiceID
        })
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }
}
