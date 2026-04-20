import SwiftUI
import SwiftData

struct MemoWindowView: View {
    let memoID: PersistentIdentifier
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var dirtyTracker = DocumentDirtyTracker()
    @State private var showCloseConfirm = false

    var body: some View {
        Group {
            if let memo = fetchMemo() {
                MemoDocumentView(memo: memo)
            } else {
                ContentUnavailableView("Memo Not Found", systemImage: "doc.questionmark",
                                        description: Text("The memo could not be loaded."))
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
                dirtyTracker.clearDirty()
                closeWindow()
            }
        } message: {
            Text("You have unsaved changes.")
        }
        .onDisappear {
            cleanupEmptyMemo()
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
            dirtyTracker.clearDirty()
        } catch {
            AppLogger.data.error("Failed to save memo: \(error.localizedDescription)")
        }
        closeWindow()
    }

    private func closeWindow() {
        dismiss()
    }

    private func fetchMemo() -> Memo? {
        let descriptor = FetchDescriptor<Memo>()
        do {
            return try modelContext.fetch(descriptor).first { $0.persistentModelID == memoID }
        } catch {
            AppLogger.data.error("Failed to fetch memo: \(error.localizedDescription)")
            return nil
        }
    }

    private func cleanupEmptyMemo() {
        guard let memo = fetchMemo() else { return }
        guard !memo.isDeleted else { return }
        if memo.lineItems.isEmpty {
            modelContext.delete(memo)
            do {
                try modelContext.save()
            } catch {
                AppLogger.data.error("Failed to cleanup empty memo: \(error.localizedDescription)")
            }
        }
    }
}
