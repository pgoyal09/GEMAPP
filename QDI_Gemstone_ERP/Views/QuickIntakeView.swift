import SwiftUI
import SwiftData

struct QuickIntakeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.navigationGuard) private var navigationGuard
    @State private var formKey = UUID()

    var body: some View {
        StoneFormView(mode: .intake, onDirtyStateChange: { dirty in
            navigationGuard?.reportDirty(dirty, onDiscard: { formKey = UUID() })
        })
        .id(formKey)
    }
}
