import Foundation
import SwiftData

@MainActor
@Observable
final class MemosViewModel {
    var memos: [Memo] = []
    
    func load(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Memo>(
            sortBy: [SortDescriptor(\.dateAssigned, order: .reverse)]
        )
        memos = (try? modelContext.fetch(descriptor)) ?? []
    }
}
