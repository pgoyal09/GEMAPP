import SwiftUI
import SwiftData

struct InvoiceWindowView: View {
    let invoiceID: PersistentIdentifier
    @Environment(\.modelContext) private var modelContext
    @State private var dirtyTracker = DocumentDirtyTracker()

    var body: some View {
        Group {
            if let invoice = fetchInvoice() {
                InvoiceDocumentView(invoice: invoice)
            } else {
                ContentUnavailableView("Invoice Not Found", systemImage: "doc.questionmark",
                                        description: Text("The invoice could not be loaded."))
            }
        }
        .environment(\.documentDirtyTracker, dirtyTracker)
        .frame(minWidth: 1100, minHeight: 760)
        .appBackground()
        
        .onDisappear {
            cleanupEmptyInvoice()
        }
    }

    private func fetchInvoice() -> Invoice? {
        let descriptor = FetchDescriptor<Invoice>()
        do {
            return try modelContext.fetch(descriptor).first { $0.persistentModelID == invoiceID }
        } catch {
            AppLogger.data.error("Failed to fetch invoice: \(error.localizedDescription)")
            return nil
        }
    }

    /// Mirror of MemoWindowView cleanup: delete invoices with 0 line items on dismiss.
    private func cleanupEmptyInvoice() {
        guard let invoice = fetchInvoice() else { return }
        if invoice.lineItems.isEmpty && invoice.status == .draft {
            modelContext.delete(invoice)
            do {
                try modelContext.save()
            } catch {
                AppLogger.data.error("Failed to cleanup empty invoice: \(error.localizedDescription)")
            }
        }
    }
}
