import SwiftUI
import SwiftData
import os

private let appLog = Logger(subsystem: "com.qdi.gemapp", category: "app")

@main
struct QDI_Gemstone_ERPApp: App {
    @StateObject private var rfidManager = RFIDManager()
    @State private var documentDirtyTracker = DocumentDirtyTracker()
    @State private var rfidCoordinator = RFIDCoordinator()
    @State private var zebraPrintService = ZebraPrintService()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Gemstone.self,
            RFIDTag.self,
            Customer.self,
            Memo.self,
            HistoryEvent.self,
            Invoice.self,
            LineItem.self,
            LotTransaction.self
        ])

        // Use a stable, explicit URL so the store survives Xcode rebuilds and DerivedData clears.
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let storeDir = appSupport.appendingPathComponent("QDI_GemstoneERP", isDirectory: true)
        try? FileManager.default.createDirectory(at: storeDir, withIntermediateDirectories: true)
        let storeURL = storeDir.appendingPathComponent("default.store")

        let modelConfiguration = ModelConfiguration(
            "default",
            schema: schema,
            url: storeURL
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            appLog.error("Persistent ModelContainer creation failed: \(error.localizedDescription, privacy: .public)")
            // Attempt a fresh store at the same location (safe for dev — preserves location, resets data)
            try? FileManager.default.removeItem(at: storeURL)
            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                appLog.fault("Could not create ModelContainer even after reset: \(error.localizedDescription, privacy: .public)")
                // Return an in-memory container as a last resort so the app can still launch
                let fallback = ModelConfiguration(isStoredInMemoryOnly: true)
                // swiftlint:disable:next force_try
                return try! ModelContainer(for: schema, configurations: [fallback])
            }
        }
    }()

    /// True when the persistent store failed and we fell back to an in-memory container.
    private var isMemoryOnlyFallback: Bool {
        sharedModelContainer.configurations.contains { $0.isStoredInMemoryOnly }
    }

    var body: some Scene {
        WindowGroup {
            ZStack(alignment: .top) {
                AppShellView()
                if isMemoryOnlyFallback {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.white)
                        Text("Database could not be loaded. Running in temporary mode — data will not be saved.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity)
                    .background(Color.red.opacity(0.85))
                }
            }
            .modelContainer(sharedModelContainer)
                .environment(\.documentDirtyTracker, documentDirtyTracker)
                .environment(\.rfidCoordinator, rfidCoordinator)
                .environment(\.zebraPrintService, zebraPrintService)
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
                    .environment(\.documentDirtyTracker, documentDirtyTracker)
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
                    .environment(\.documentDirtyTracker, documentDirtyTracker)
            } else {
                ContentUnavailableView("Invalid Invoice", systemImage: "dollarsign.circle", description: Text("No invoice selected."))
            }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1320, height: 860)
        .windowResizability(.contentMinSize)
    }
}
