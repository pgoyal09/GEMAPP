import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var rfidCoordinator = RFIDCoordinator()

    var body: some View {
        AppShellView()
            .environment(\.rfidCoordinator, rfidCoordinator)
    }
}
