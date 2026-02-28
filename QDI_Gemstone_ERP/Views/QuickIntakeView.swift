import SwiftUI
import SwiftData

struct QuickIntakeView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        StoneFormView(mode: .intake)
    }
}
