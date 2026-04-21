import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

// MARK: - App Delegate (handles ⌘Q with unsaved document check)

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let dirtyWindows = NSApp.windows.filter { $0.isDocumentEdited }
        guard !dirtyWindows.isEmpty else { return .terminateNow }

        // Show a single aggregated alert for all dirty windows
        let count = dirtyWindows.count
        dirtyWindows.first?.makeKeyAndOrderFront(nil)
        let alert = NSAlert()
        alert.messageText = count == 1
            ? "You have unsaved changes"
            : "You have unsaved changes in \(count) windows"
        alert.informativeText = count == 1
            ? "Do you want to save your changes before quitting?"
            : "Do you want to save all changes before quitting?"
        alert.addButton(withTitle: "Save All & Quit")
        alert.addButton(withTitle: "Discard & Quit")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            NotificationCenter.default.post(name: .appWillTerminateSaveAll, object: nil)
            // Allow up to 3 seconds for saves to complete, polling every 100ms
            let deadline = Date(timeIntervalSinceNow: 3.0)
            while Date() < deadline {
                RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
                let stillDirty = NSApp.windows.contains { $0.isDocumentEdited }
                if !stillDirty { break }
            }
            if NSApp.windows.contains(where: { $0.isDocumentEdited }) {
                AppLogger.data.warning("Some windows may not have saved before quit")
            }
            return .terminateNow
        case .alertSecondButtonReturn:
            return .terminateNow
        default:
            return .terminateCancel
        }
    }
}

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
    // Keyboard shortcut notifications
    static let menuContextNewItem = Notification.Name("menuContextNewItem")
    static let menuFocusSearch = Notification.Name("menuFocusSearch")
    static let menuExport = Notification.Name("menuExport")
    static let menuPrint = Notification.Name("menuPrint")
    static let menuRefreshData = Notification.Name("menuRefreshData")
    static let menuQuickIntake = Notification.Name("menuQuickIntake")
    static let menuReviewQueue = Notification.Name("menuReviewQueue")
    static let menuReconcile = Notification.Name("menuReconcile")
    static let menuAgingReport = Notification.Name("menuAgingReport")
    static let menuCloudBackup = Notification.Name("menuCloudBackup")
    static let menuEscapeDismiss = Notification.Name("menuEscapeDismiss")
    // App lifecycle
    static let appWillTerminateSaveAll = Notification.Name("appWillTerminateSaveAll")
}

@main
struct QDIGemstoneERPApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var rfidManager = RFIDManager()
    @State private var rfidCoordinator: RFIDCoordinator?
    @State private var showMigrationFailureAlert = false
    @State private var migrationError: String = ""
    @State private var apiServer: APIServer?
    @State private var backupScheduler = BackupScheduler()
    @State private var openDocTracker = OpenDocumentTracker()

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
        ReconciliationRecord.self,
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
            let container = try ModelContainer(
                for: schema,
                migrationPlan: GemAppMigrationPlan.self,
                configurations: [config]
            )
            #if DEBUG
            // Seed demo data only if user opted in during onboarding.
            // Previously this ran unconditionally in DEBUG builds.
            if UserDefaults.standard.bool(forKey: "seedDemoData") {
                do {
                    try DemoDataService.seedIfNeeded(modelContext: container.mainContext)
                } catch {
                    AppLogger.data.error("Failed to seed demo data: \(error.localizedDescription)")
                }
            }
            #endif
            return container
        } catch {
            // Migration failed — don't silently delete user data.
            // Create a minimal in-memory container so the app can launch and show the alert.
            AppLogger.data.error("ModelContainer failed: \(error.localizedDescription)")
            migrationDidFail = true
            migrationErrorMessage = error.localizedDescription
            // Return an in-memory container so the app can launch and show the migration alert.
            // This container is ephemeral — UI interaction is blocked by migrationDidFail.
            do {
                let inMemoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                let container = try ModelContainer(for: schema, configurations: [inMemoryConfig])
                container.mainContext.autosaveEnabled = false
                return container
            } catch {
                fatalError("Could not create even an in-memory ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        // Main window
        WindowGroup {
            AppShellView()
                .frame(minWidth: 1100, minHeight: 700)
                .environment(\.rfidCoordinator, rfidCoordinator)
                .environment(\.openDocumentTracker, openDocTracker)
                .onAppear {
                    setupRFID()
                    startAPIServer()
                    runPhase2Migrations()
                    backupScheduler.configure(container: sharedModelContainer)
                    if Self.migrationDidFail {
                        migrationError = Self.migrationErrorMessage
                        showMigrationFailureAlert = true
                    }
                }
                .disabled(Self.migrationDidFail) // Block all interaction when running in-memory fallback
                .overlay {
                    if Self.migrationDidFail {
                        Color.black.opacity(0.5)
                            .ignoresSafeArea()
                            .allowsHitTesting(false)
                    }
                }
                .alert("Data Migration Failed", isPresented: $showMigrationFailureAlert) {
                    Button("Try Again") {
                        NSApplication.shared.terminate(nil)
                    }
                    Button("Export Store & Reset", role: .destructive) {
                        // Use NSSavePanel for sandbox-compatible export
                        let panel = NSSavePanel()
                        panel.nameFieldStringValue = "GemApp-store-backup-\(ISO8601DateFormatter().string(from: Date())).sqlite"
                        panel.allowedContentTypes = [.data]
                        panel.canCreateDirectories = true
                        if panel.runModal() == .OK, let saveURL = panel.url {
                            try? FileManager.default.copyItem(at: Self.storeURL, to: saveURL)
                            AppLogger.data.info("Store backed up to: \(saveURL.lastPathComponent)")
                        }
                        try? FileManager.default.removeItem(at: Self.storeURL)
                        NSApplication.shared.terminate(nil)
                    }
                    Button("Reset Data", role: .destructive) {
                        do {
                            try FileManager.default.removeItem(at: Self.storeURL)
                        } catch {
                            AppLogger.data.error("Failed to delete store file: \(error.localizedDescription)")
                        }
                        NSApplication.shared.terminate(nil)
                    }
                } message: {
                    Text("The database could not be migrated to the new schema.\n\n• Try Again: re-launches the app to retry\n• Export & Reset: saves a copy of your data file, then resets\n• Reset Data: deletes all data and starts fresh\n\nError: \(migrationError)")
                }
        }
        .defaultSize(width: 1400, height: 900)
        .modelContainer(sharedModelContainer)
        .commands {
            // File → New items
            CommandGroup(replacing: .newItem) {
                Button("New Item") {
                    NotificationCenter.default.post(name: .menuContextNewItem, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)

                Divider()

                Button("New Diamond") {
                    NotificationCenter.default.post(name: .menuNewDiamond, object: nil)
                }

                Button("New Gemstone") {
                    NotificationCenter.default.post(name: .menuNewGemstone, object: nil)
                }

                Button("New Lot") {
                    NotificationCenter.default.post(name: .menuNewLot, object: nil)
                }
            }

            // Edit → Undo / Redo + Find
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

            // Edit → Find / Search
            CommandGroup(after: .textEditing) {
                Button("Find / Filter…") {
                    NotificationCenter.default.post(name: .menuFocusSearch, object: nil)
                }
                .keyboardShortcut("f", modifiers: .command)
            }

            // File → Export / Print / Refresh
            CommandGroup(after: .importExport) {
                Button("Export…") {
                    NotificationCenter.default.post(name: .menuExport, object: nil)
                }
                .keyboardShortcut("e", modifiers: .command)

                Button("Print…") {
                    NotificationCenter.default.post(name: .menuPrint, object: nil)
                }
                .keyboardShortcut("p", modifiers: .command)

                Divider()

                Button("Refresh Data") {
                    NotificationCenter.default.post(name: .menuRefreshData, object: nil)
                }
                .keyboardShortcut("r", modifiers: .command)

                Button("Cloud Backup…") {
                    NotificationCenter.default.post(name: .menuCloudBackup, object: nil)
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
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
                .keyboardShortcut("m", modifiers: [.command, .shift])

                Button("New Invoice") {
                    NotificationCenter.default.post(name: .menuNewInvoice, object: nil)
                }
                .keyboardShortcut("i", modifiers: .command)

                Divider()

                Button("Quick Intake") {
                    NotificationCenter.default.post(name: .menuQuickIntake, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])

                Button("Review Queue") {
                    NotificationCenter.default.post(name: .menuReviewQueue, object: nil)
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])

                Button("Reconcile") {
                    NotificationCenter.default.post(name: .menuReconcile, object: nil)
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])

                Button("Aging Report") {
                    NotificationCenter.default.post(name: .menuAgingReport, object: nil)
                }
                .keyboardShortcut("a", modifiers: [.command, .shift])
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
                    .environment(\.openDocumentTracker, openDocTracker)
            }
        }
        .defaultSize(width: 1200, height: 800)
        .modelContainer(sharedModelContainer)

        // Invoice document windows
        WindowGroup("Invoice", id: "invoice", for: PersistentIdentifier.self) { $invoiceID in
            if let id = invoiceID {
                InvoiceWindowView(invoiceID: id)
                    .environment(\.openDocumentTracker, openDocTracker)
            }
        }
        .defaultSize(width: 1200, height: 800)
        .modelContainer(sharedModelContainer)
    }

    // MARK: - API Server

    private static let apiKeychainService = "com.qdi.gemstone-erp.api"
    private static let apiKeychainAccount = "bearerToken"

    private func startAPIServer() {
        guard apiServer == nil else { return }
        // Load token from Keychain; migrate from UserDefaults if needed
        var token = KeychainHelper.load(service: Self.apiKeychainService, account: Self.apiKeychainAccount)
        if token == nil {
            // One-time migration from UserDefaults → Keychain
            if let legacyToken = UserDefaults.standard.string(forKey: "apiAuthToken"), legacyToken != "qdi-dev-token" {
                KeychainHelper.save(legacyToken, service: Self.apiKeychainService, account: Self.apiKeychainAccount)
                UserDefaults.standard.removeObject(forKey: "apiAuthToken")
                token = legacyToken
            } else {
                // Generate a random token for first launch
                let newToken = UUID().uuidString
                KeychainHelper.save(newToken, service: Self.apiKeychainService, account: Self.apiKeychainAccount)
                UserDefaults.standard.removeObject(forKey: "apiAuthToken")
                token = newToken
            }
        }
        guard let resolvedToken = token else {
            AppLogger.data.error("API token could not be loaded or generated")
            return
        }
        let server = APIServer(modelContainer: sharedModelContainer, bearerToken: resolvedToken)
        do {
            try server.start()
            apiServer = server
        } catch {
            AppLogger.data.error("API server failed to start: \(error.localizedDescription)")
        }
    }

    // MARK: - Phase 2 Migrations

    /// Each sub-migration runs independently with its own completion flag.
    /// If the app crashes mid-migration, only the incomplete step re-runs on next launch.
    /// Each step is idempotent: re-running it on already-migrated data is a no-op.
    private func runPhase2Migrations() {
        let ctx = sharedModelContainer.mainContext

        // Step 1: pair migration (legacy — no longer converts, pairs are a valid grouping now)
        // This step is kept for backward compat; the flag prevents re-execution.
        if !UserDefaults.standard.bool(forKey: "phase2_pairToSingle_complete") {
            do {
                let allStones = try ctx.fetch(FetchDescriptor<Gemstone>())
                var changed = false
                for stone in allStones where stone.grouping == .pair {
                    stone.grouping = .single
                    changed = true
                }
                if changed { try ctx.save() }
                UserDefaults.standard.set(true, forKey: "phase2_pairToSingle_complete")
                AppLogger.data.info("Phase 2 step 1 (pair→single) completed")
            } catch {
                AppLogger.data.error("Phase 2 step 1 failed: \(error.localizedDescription)")
                NotificationCenter.default.post(
                    name: NSNotification.Name("phase2MigrationFailed"),
                    object: "Migration step 1 (grouping) failed. Will retry on next launch. Error: \(error.localizedDescription)"
                )
            }
        }

        // Step 2: split fluorescence into intensity + color
        if !UserDefaults.standard.bool(forKey: "phase2_fluorescenceSplit_complete") {
            do {
                let allStones = try ctx.fetch(FetchDescriptor<Gemstone>())
                var changed = false
                for stone in allStones {
                    if stone.fluorescenceIntensity == nil && !stone.fluorescence.isEmpty {
                        stone.fluorescenceIntensity = stone.fluorescence
                        stone.fluorescenceColor = "N"
                        changed = true
                    }
                }
                if changed { try ctx.save() }
                UserDefaults.standard.set(true, forKey: "phase2_fluorescenceSplit_complete")
                AppLogger.data.info("Phase 2 step 2 (fluorescence split) completed")
            } catch {
                AppLogger.data.error("Phase 2 step 2 failed: \(error.localizedDescription)")
                NotificationCenter.default.post(
                    name: NSNotification.Name("phase2MigrationFailed"),
                    object: "Migration step 2 (fluorescence) failed. Will retry on next launch. Error: \(error.localizedDescription)"
                )
            }
        }

        // Mark overall completion for backward compatibility
        if UserDefaults.standard.bool(forKey: "phase2_pairToSingle_complete") &&
           UserDefaults.standard.bool(forKey: "phase2_fluorescenceSplit_complete") {
            UserDefaults.standard.set(true, forKey: "phase2MigrationsComplete")
        }
    }

    private func setupRFID() {
        if rfidCoordinator == nil {
            rfidCoordinator = RFIDCoordinator(rfidService: rfidManager)
        }
    }
}
