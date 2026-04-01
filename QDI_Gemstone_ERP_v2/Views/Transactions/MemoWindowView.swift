import SwiftUI
import SwiftData

struct MemoWindowView: View {
    let memoID: PersistentIdentifier
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var dirtyTracker = DocumentDirtyTracker()

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
        .onExitCommand {
            if dirtyTracker.isDirty {
                dirtyTracker.showUnsavedAlert = true
            } else {
                dismiss()
            }
        }
        .alert("Unsaved Changes", isPresented: $dirtyTracker.showUnsavedAlert) {
            Button("Keep Editing", role: .cancel) {}
            Button("Discard", role: .destructive) {
                dismiss()
            }
        } message: {
            Text("You have unsaved changes. Discard them?")
        }
        .onDisappear {
            cleanupEmptyMemo()
        }
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
