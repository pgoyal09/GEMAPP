import SwiftUI
import SwiftData
import os

private let appLog = Logger(subsystem: "com.qdi.gemapp", category: "app")

@main
struct QDI_Gemstone_ERPApp: App {
    @StateObject private var rfidManager = RFIDManager()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Gemstone.self,
            RFIDTag.self,
            Customer.self,
            Memo.self,
            HistoryEvent.self,
            Invoice.self,
            LineItem.self
        ])
        let modelConfiguration = ModelConfiguration(
            "default",
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            appLog.error("Persistent ModelContainer creation failed: \(error.localizedDescription, privacy: .public)")
            appLog.warning("Falling back to in-memory store to avoid destructive file reset")

            let inMemoryConfiguration = ModelConfiguration(
                "recovery_in_memory",
                schema: schema,
                isStoredInMemoryOnly: true
            )
            do {
                return try ModelContainer(for: schema, configurations: [inMemoryConfiguration])
            } catch {
                fatalError("Could not create recovery ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(sharedModelContainer)
                .environmentObject(rfidManager)
                .onAppear {
                    DataSeeder.seedIfNeeded(modelContext: sharedModelContainer.mainContext)
                    RFIDScanService.migrateLegacyFieldsIfNeeded(modelContext: sharedModelContainer.mainContext)
                    rfidManager.autoConnect()
                }
        }
        .defaultSize(width: 1200, height: 780)
        .windowResizability(.contentMinSize)
        .defaultPosition(.center)

        WindowGroup(id: "memo", for: PersistentIdentifier.self) { $memoID in
            if let id = memoID {
                MemoWindowView(memoID: id)
                    .modelContainer(sharedModelContainer)
            } else {
                ContentUnavailableView("Invalid Memo", systemImage: "doc.text", description: Text("No memo selected."))
            }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1320, height: 860)
        .windowResizability(.contentMinSize)

        WindowGroup(id: "invoice", for: PersistentIdentifier.self) { $invoiceID in
            if let id = invoiceID {
                InvoiceWindowView(invoiceID: id)
                    .modelContainer(sharedModelContainer)
            } else {
                ContentUnavailableView("Invalid Invoice", systemImage: "dollarsign.circle", description: Text("No invoice selected."))
            }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1320, height: 860)
        .windowResizability(.contentMinSize)
    }
}
