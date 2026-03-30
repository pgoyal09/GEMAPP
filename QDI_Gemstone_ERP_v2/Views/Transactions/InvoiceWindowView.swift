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
        .preferredColorScheme(.dark)
    }

    private func fetchInvoice() -> Invoice? {
        let descriptor = FetchDescriptor<Invoice>()
        return (try? modelContext.fetch(descriptor))?.first { $0.persistentModelID == invoiceID }
    }
}
