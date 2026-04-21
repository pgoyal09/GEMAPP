import SwiftUI
import SwiftData

struct InvoiceWindowView: View {
    let invoiceID: PersistentIdentifier
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openDocumentTracker) private var openDocTracker
    @State private var dirtyTracker = DocumentDirtyTracker()
    @State private var showCloseConfirm = false

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
        .onKeyPress(.escape) {
            requestClose()
            return .handled
        }
        .alert("Unsaved Changes", isPresented: $showCloseConfirm) {
            Button("Keep Editing", role: .cancel) {}
            Button("Save & Exit") {
                saveAndClose()
            }
            Button("Discard", role: .destructive) {
                dirtyTracker.clearInvoiceDirty()
                closeWindow()
            }
        } message: {
            Text("You have unsaved changes.")
        }
        .onAppear {
            openDocTracker.trackOpen(invoiceID: invoiceID)
        }
        .onDisappear {
            openDocTracker.trackClose(invoiceID: invoiceID)
            cleanupEmptyInvoice()
        }
        .onChange(of: dirtyTracker.hasAnyDirty) { _, isDirty in
            // Sync dirty state to NSWindow so AppDelegate can check on ⌘Q
            NSApp.keyWindow?.isDocumentEdited = isDirty
        }
        .onReceive(NotificationCenter.default.publisher(for: .appWillTerminateSaveAll)) { _ in
            if dirtyTracker.hasAnyDirty {
                try? modelContext.save()
                dirtyTracker.clearInvoiceDirty()
            }
        }
    }

    private func requestClose() {
        if dirtyTracker.hasAnyDirty {
            showCloseConfirm = true
        } else {
            closeWindow()
        }
    }

    private func saveAndClose() {
        do {
            try modelContext.save()
            dirtyTracker.clearInvoiceDirty()
        } catch {
            AppLogger.data.error("Failed to save invoice: \(error.localizedDescription)")
        }
        closeWindow()
    }

    private func closeWindow() {
        // dismiss() is unreliable on WindowGroup — use NSApp.keyWindow?.close() per BUILD-SPEC
        NSApp.keyWindow?.close()
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

    private func cleanupEmptyInvoice() {
        guard let invoice = fetchInvoice() else { return }
        guard !invoice.isDeleted else { return }
        if invoice.lineItems.isEmpty && invoice.status == .draft {
            do {
                try InvoiceService.deleteInvoice(invoice, modelContext: modelContext)
            } catch {
                AppLogger.data.error("Failed to cleanup empty invoice: \(error.localizedDescription)")
            }
        }
    }
}
