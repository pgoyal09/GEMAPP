import SwiftUI
import SwiftData

/// Owns the overdue-memo notification state for AppShellView.
///
/// Keeps the shell view free of direct data-fetch / business-filtering logic
/// while preserving identical badge-count and popover behavior.
@Observable
@MainActor
final class ShellNotificationViewModel {
    private let modelContext: ModelContext

    /// Overdue memos (status == .onMemo, age > 60 days), oldest first.
    private(set) var overdueMemos: [Memo] = []

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        refresh()
    }

    /// Re-fetches the overdue memo list from the store.
    func refresh() {
        let descriptor = FetchDescriptor<Memo>(
            sortBy: [SortDescriptor(\Memo.createdAt, order: .forward)]
        )
        let all = (try? modelContext.fetch(descriptor)) ?? []
        overdueMemos = all.filter { $0.status == .onMemo && $0.ageInDays > 60 }
    }
}
