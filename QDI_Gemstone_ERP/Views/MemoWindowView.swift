import SwiftUI
import SwiftData
import AppKit

/// Document window for a Memo. Fetches by PersistentIdentifier; shows ContentUnavailableView if not found.
struct MemoWindowView: View {
    let memoID: PersistentIdentifier
    @Environment(\.modelContext) private var modelContext
    @Environment(\.documentDirtyTracker) private var documentDirtyTracker
    @State private var showLeaveWithoutSavingAlert = false

    var body: some View {
        Group {
            if let memo = fetchMemo() {
                MemoDocumentView(memo: memo) {
                    // onDelete - list will refresh when user returns to Memos
                }
            } else {
                ContentUnavailableView(
                    "Memo Not Found",
                    systemImage: "doc.text",
                    description: Text("This memo may have been deleted.")
                )
            }
        }
        .frame(minWidth: 1100, minHeight: 760)
        .background {
            Button("") {
                let isDirty = modelContext.hasChanges || (documentDirtyTracker?.hasUnsavedMemo ?? false)
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
                documentDirtyTracker?.hasUnsavedMemo = false
                modelContext.rollback()
                NSApp.keyWindow?.close()
            }
        } message: {
            Text("Your changes will not be saved.")
        }
    }

    private func fetchMemo() -> Memo? {
        var descriptor = FetchDescriptor<Memo>(predicate: #Predicate<Memo> { memo in
            memo.persistentModelID == memoID
        })
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }
}
