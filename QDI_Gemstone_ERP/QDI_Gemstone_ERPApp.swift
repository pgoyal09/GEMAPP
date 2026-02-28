import SwiftUI
import SwiftData

@main
struct QDI_Gemstone_ERPApp: App {
    @StateObject private var rfidManager = RFIDManager()
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Gemstone.self,
            Customer.self,
            Memo.self,
            HistoryEvent.self,
            Invoice.self,
            LineItem.self
        ])
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let modelConfiguration = ModelConfiguration(
            "default",
            schema: schema,
            isStoredInMemoryOnly: false
        )
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // Schema changed or store corrupted: remove store files and retry once.
            // SwiftData puts "default.store" in Application Support root when using name "default".
            let fm = FileManager.default
            for suffix in ["", "-shm", "-wal"] {
                let url = appSupport.appending(path: "default.store\(suffix)")
                try? fm.removeItem(at: url)
            }
            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
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
