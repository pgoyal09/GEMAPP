import SwiftUI
import SwiftData

// MARK: - Menu Command Notifications

extension Notification.Name {
    static let menuNewMemo = Notification.Name("menuNewMemo")
    static let menuNewInvoice = Notification.Name("menuNewInvoice")
    static let menuNewStone = Notification.Name("menuNewStone")
    static let menuNewDiamond = Notification.Name("menuNewDiamond")
    static let menuNewGemstone = Notification.Name("menuNewGemstone")
    static let menuNewLot = Notification.Name("menuNewLot")
    static let menuToggleSidebar = Notification.Name("menuToggleSidebar")
    static let menuOpenSettings = Notification.Name("menuOpenSettings")
    static let menuOpenGlossary = Notification.Name("menuOpenGlossary")
    static let menuOpenHelpCenter = Notification.Name("menuOpenHelpCenter")
}

@main
struct QDIGemstoneERPApp: App {
    @State private var rfidManager = RFIDManager()
    @State private var rfidCoordinator: RFIDCoordinator?
    @State private var showMigrationFailureAlert = false
    @State private var migrationError: String = ""
    @State private var apiServer: APIServer?
    @State private var backupScheduler = BackupScheduler()

    private static let storeURL = URL.applicationSupportDirectory.appending(path: "QDIGemstoneERP_v2.store")
    private static let schema = Schema([
        Gemstone.self,
        Customer.self,
        Memo.self,
        Invoice.self,
        LineItem.self,
        LotTransaction.self,
        HistoryEvent.self,
        RFIDTag.self,
        Payment.self,
        PaymentReminder.self,
        BackupManifest.self,
    ])

    /// Flag set when the initial container creation fails, so the app can show an alert.
    private static var migrationDidFail = false
    private static var migrationErrorMessage = ""

    var sharedModelContainer: ModelContainer = {
        // groupAppContainerIdentifier is nil so all windows share one store.
        // Multi-window consistency is achieved via NotificationCenter-based refresh:
        // each document window posts .dataStoreDidChange on save; list views
        // observe it and re-fetch, preventing stale data across windows.
        let config = ModelConfiguration(schema: schema, url: storeURL)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Migration failed — don't silently delete user data.
            // Create a minimal in-memory container so the app can launch and show the alert.
            AppLogger.data.error("ModelContainer failed: \(error.localizedDescription)")
            migrationDidFail = true
            migrationErrorMessage = error.localizedDescription
            // Return an in-memory container so the app can at least render UI
            do {
                let inMemoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                return try ModelContainer(for: schema, configurations: [inMemoryConfig])
            } catch {
                fatalError("Could not create even an in-memory ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        // Main window
        WindowGroup {
            AppShellView()
                .environment(\.rfidCoordinator, rfidCoordinator)
                .onAppear {
                    setupRFID()
                    startAPIServer()
                    runPhase2Migrations()
                    backupScheduler.configure(container: sharedModelContainer)
                    #if DEBUG
                    // Only seed demo data in debug builds — production starts with empty database
                    do {
                        try DemoDataService.seedIfNeeded(modelContext: sharedModelContainer.mainContext)
                    } catch {
                        AppLogger.data.error("Failed to seed demo data: \(error.localizedDescription)")
                    }
                    #endif
                    if Self.migrationDidFail {
                        migrationError = Self.migrationErrorMessage
                        showMigrationFailureAlert = true
                    }
                }
                .alert("Data Migration Failed", isPresented: $showMigrationFailureAlert) {
                    Button("Try Again") {
                        // Relaunch the app to retry migration
                        NSApplication.shared.terminate(nil)
                    }
                    Button("Reset Data", role: .destructive) {
                        do {
                            try FileManager.default.removeItem(at: Self.storeURL)
                        } catch {
                            AppLogger.data.error("Failed to delete store file: \(error.localizedDescription)")
                        }
                        // Relaunch after reset
                        NSApplication.shared.terminate(nil)
                    }
                } message: {
                    Text("The database could not be migrated to the new schema. You can try again or reset all data.\n\nError: \(migrationError)")
                }
        }
        .modelContainer(sharedModelContainer)
        .commands {
            // File → New items
            CommandGroup(replacing: .newItem) {
                Button("New Diamond") {
                    NotificationCenter.default.post(name: .menuNewDiamond, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("New Gemstone") {
                    NotificationCenter.default.post(name: .menuNewGemstone, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])

                Button("New Lot") {
                    NotificationCenter.default.post(name: .menuNewLot, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command, .option])
            }

            // Edit → Undo / Redo
            CommandGroup(replacing: .undoRedo) {
                Button("Undo") {
                    NSApp.sendAction(Selector(("undo:")), to: nil, from: nil)
                }
                .keyboardShortcut("z", modifiers: .command)

                Button("Redo") {
                    NSApp.sendAction(Selector(("redo:")), to: nil, from: nil)
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
            }

            // View → Toggle Sidebar
            CommandGroup(after: .sidebar) {
                Button("Toggle Sidebar") {
                    NotificationCenter.default.post(name: .menuToggleSidebar, object: nil)
                }
                .keyboardShortcut("s", modifiers: [.command, .option])
            }

            // Transactions menu
            CommandMenu("Transactions") {
                Button("New Memo") {
                    NotificationCenter.default.post(name: .menuNewMemo, object: nil)
                }
                .keyboardShortcut("m", modifiers: .command)

                Button("New Invoice") {
                    NotificationCenter.default.post(name: .menuNewInvoice, object: nil)
                }
                .keyboardShortcut("i", modifiers: .command)
            }

            // Help menu
            CommandGroup(replacing: .help) {
                Button("QDI Help Center") {
                    NotificationCenter.default.post(name: .menuOpenHelpCenter, object: nil)
                }
                .keyboardShortcut("?", modifiers: .command)

                Divider()

                Button("Gemstone Glossary") {
                    NotificationCenter.default.post(name: .menuOpenGlossary, object: nil)
                }
            }

            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    NotificationCenter.default.post(name: .menuOpenSettings, object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }

        // Memo document windows
        WindowGroup("Memo", id: "memo", for: PersistentIdentifier.self) { $memoID in
            if let id = memoID {
                MemoWindowView(memoID: id)
            }
        }
        .modelContainer(sharedModelContainer)

        // Invoice document windows
        WindowGroup("Invoice", id: "invoice", for: PersistentIdentifier.self) { $invoiceID in
            if let id = invoiceID {
                InvoiceWindowView(invoiceID: id)
            }
        }
        .modelContainer(sharedModelContainer)
    }

    // MARK: - API Server

    private func startAPIServer() {
        guard apiServer == nil else { return }
        let server = APIServer(modelContainer: sharedModelContainer, bearerToken: "qdi-dev-token")
        do {
            try server.start()
            apiServer = server
        } catch {
            AppLogger.data.error("API server failed to start: \(error.localizedDescription)")
        }
    }

    // MARK: - Phase 2 Migrations

    private func runPhase2Migrations() {
        let ctx = sharedModelContainer.mainContext
        do {
            let allDescriptor = FetchDescriptor<Gemstone>()
            let allStones = try ctx.fetch(allDescriptor)
            var changed = false

            // ONE-TIME: convert all pair → single grouping
            for stone in allStones where stone.grouping == .pair {
                stone.grouping = .single
                changed = true
            }

            // ONE-TIME: split fluorescence into intensity + color
            for stone in allStones {
                if stone.fluorescenceIntensity == nil && !stone.fluorescence.isEmpty {
                    stone.fluorescenceIntensity = stone.fluorescence
                    stone.fluorescenceColor = "N"
                    changed = true
                }
            }

            if changed {
                try ctx.save()
                AppLogger.data.info("Phase 2 migration completed")
            }
        } catch {
            AppLogger.data.error("Phase 2 migration failed: \(error.localizedDescription)")
        }
    }

    private func setupRFID() {
        if rfidCoordinator == nil {
            rfidCoordinator = RFIDCoordinator(rfidService: rfidManager)
        }
    }
}
