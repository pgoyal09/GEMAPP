import SwiftUI
import SwiftData
import AppKit

/// Document window for an Invoice. Fetches by PersistentIdentifier; shows ContentUnavailableView if not found.
struct InvoiceWindowView: View {
    let invoiceID: PersistentIdentifier
    @Environment(\.modelContext) private var modelContext
    @Environment(\.documentDirtyTracker) private var documentDirtyTracker
    @State private var showLeaveWithoutSavingAlert = false

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
        .background {
            Button("") {
                let isDirty = modelContext.hasChanges || (documentDirtyTracker?.hasUnsavedInvoice ?? false)
                if isDirty {
                    showLeaveWithoutSavingAlert = true
                } else {
                    modelContext.rollback()
                    NSApp.keyWindow?.close()
                }
            }
            .keyboardShortcut(.escape, modifiers: [])
            .frame(width: 0, height: 0)
            .opacity(0)
        }
        .alert("Leave without saving?", isPresented: $showLeaveWithoutSavingAlert) {
            Button("Keep Editing", role: .cancel) {}
            Button("Discard", role: .destructive) {
                documentDirtyTracker?.hasUnsavedInvoice = false
                modelContext.rollback()
                NSApp.keyWindow?.close()
            }
        } message: {
            Text("Your changes will not be saved.")
        }
    }

    private func fetchInvoice() -> Invoice? {
        var descriptor = FetchDescriptor<Invoice>(predicate: #Predicate<Invoice> { invoice in
            invoice.persistentModelID == invoiceID
        })
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }
}
