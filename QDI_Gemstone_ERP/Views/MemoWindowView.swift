import SwiftUI
import SwiftData
import AppKit

/// Document window for a Memo. Fetches by PersistentIdentifier; shows ContentUnavailableView if not found.
struct MemoWindowView: View {
    let memoID: PersistentIdentifier
    @Environment(\.modelContext) private var modelContext
    @Environment(\.documentDirtyTracker) private var documentDirtyTracker
    @State private var showLeaveWithoutSavingAlert = false
    @State private var hostWindow: NSWindow?

    private func closeWindow() { hostWindow?.close() }

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
        .background(AppColors.background)
        .preferredColorScheme(.dark)
        .background {
            Button("") {
                let isDirty = modelContext.hasChanges || (documentDirtyTracker?.hasUnsavedMemo ?? false)
                if isDirty {
                    showLeaveWithoutSavingAlert = true
                } else {
                    modelContext.rollback()
                    closeWindow()
                }
            }
            .keyboardShortcut(.escape, modifiers: [])
            .frame(width: 0, height: 0)
            .opacity(0)
        }
        .alert("Leave without saving?", isPresented: $showLeaveWithoutSavingAlert) {
            Button("Keep Editing", role: .cancel) {}
            Button("Save and Close") { documentDirtyTracker?.onSaveAndClose?() }
            Button("Discard edits and leave", role: .destructive) {
                documentDirtyTracker?.hasUnsavedMemo = false
                modelContext.rollback()
                closeWindow()
            }
        } message: {
            Text("Your changes will not be saved.")
        }
        .onAppear {
            hostWindow = NSApp.keyWindow
            DispatchQueue.main.async { NSApp.keyWindow?.makeFirstResponder(nil) }
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
