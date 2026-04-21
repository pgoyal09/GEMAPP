import SwiftUI
import SwiftData

struct MemoWindowView: View {
    let memoID: PersistentIdentifier
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openDocumentTracker) private var openDocTracker
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
                dirtyTracker.clearMemoDirty()
                closeWindow()
            }
        } message: {
            Text("You have unsaved changes.")
        }
        .onAppear {
            openDocTracker.trackOpen(memoID: memoID)
            // Lock all stones currently on this memo
            if let memo = fetchMemo() {
                for item in memo.lineItems {
                    if let stoneID = item.gemstone?.persistentModelID {
                        openDocTracker.lockStone(stoneID, by: "Memo #\(memo.referenceNumber)")
                    }
                }
            }
        }
        .onDisappear {
            // Unlock all stones when window closes
            if let memo = fetchMemo() {
                let stoneIDs = Set(memo.lineItems.compactMap { $0.gemstone?.persistentModelID })
                openDocTracker.unlockStones(stoneIDs)
            }
            openDocTracker.trackClose(memoID: memoID)
            cleanupEmptyMemo()
        }
        .onChange(of: dirtyTracker.hasAnyDirty) { _, isDirty in
            // Sync dirty state to NSWindow so AppDelegate can check on ⌘Q
            NSApp.keyWindow?.isDocumentEdited = isDirty
        }
        .onReceive(NotificationCenter.default.publisher(for: .appWillTerminateSaveAll)) { _ in
            if dirtyTracker.hasAnyDirty {
                try? modelContext.save()
                dirtyTracker.clearMemoDirty()
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
            dirtyTracker.clearMemoDirty()
        } catch {
            AppLogger.data.error("Failed to save memo: \(error.localizedDescription)")
        }
        closeWindow()
    }

    private func closeWindow() {
        // dismiss() is unreliable on WindowGroup — use NSApp.keyWindow?.close() per BUILD-SPEC
        NSApp.keyWindow?.close()
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
        // Only cleanup if the memo has no customer AND no line items.
        // A memo with a customer assigned but no items yet should be preserved.
        if memo.lineItems.isEmpty && memo.customer == nil {
            modelContext.delete(memo)
            do {
                try modelContext.save()
            } catch {
                AppLogger.data.error("Failed to cleanup empty memo: \(error.localizedDescription)")
            }
        }
    }
}
