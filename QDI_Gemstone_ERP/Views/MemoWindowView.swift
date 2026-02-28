import SwiftUI
import SwiftData

/// Document window for a Memo. Fetches by PersistentIdentifier; shows ContentUnavailableView if not found.
struct MemoWindowView: View {
    let memoID: PersistentIdentifier
    @Environment(\.modelContext) private var modelContext

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
    }

    private func fetchMemo() -> Memo? {
        var descriptor = FetchDescriptor<Memo>(predicate: #Predicate<Memo> { memo in
            memo.persistentModelID == memoID
        })
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }
}
