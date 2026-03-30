import SwiftUI
import SwiftData

// MARK: - Menu Command Notifications

extension Notification.Name {
    static let menuNewMemo = Notification.Name("menuNewMemo")
    static let menuNewInvoice = Notification.Name("menuNewInvoice")
    static let menuNewStone = Notification.Name("menuNewStone")
    static let menuToggleSidebar = Notification.Name("menuToggleSidebar")
    static let menuOpenSettings = Notification.Name("menuOpenSettings")
}

@main
struct QDIGemstoneERPApp: App {
    @State private var rfidManager = RFIDManager()
    @State private var rfidCoordinator: RFIDCoordinator?
    @State private var showMigrationFailureAlert = false
    @State private var migrationError: String = ""

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
    ])

    /// Flag set when the initial container creation fails, so the app can show an alert.
    private static var migrationDidFail = false
    private static var migrationErrorMessage = ""

    var sharedModelContainer: ModelContainer = {
        let config = ModelConfiguration(schema: schema, url: storeURL)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Migration failed — don't silently delete user data.
            // Create a minimal in-memory container so the app can launch and show the alert.
            print("[App] ModelContainer failed (\(error)). Will prompt user for action.")
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
                        try? FileManager.default.removeItem(at: Self.storeURL)
                        // Relaunch after reset
                        NSApplication.shared.terminate(nil)
                    }
                } message: {
                    Text("The database could not be migrated to the new schema. You can try again or reset all data.\n\nError: \(migrationError)")
                }
        }
        .modelContainer(sharedModelContainer)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Memo") {
                    NotificationCenter.default.post(name: .menuNewMemo, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("New Invoice") {
                    NotificationCenter.default.post(name: .menuNewInvoice, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])

                Button("New Stone") {
                    NotificationCenter.default.post(name: .menuNewStone, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command, .option])
            }
            CommandGroup(after: .sidebar) {
                Button("Toggle Sidebar") {
                    NotificationCenter.default.post(name: .menuToggleSidebar, object: nil)
                }
                .keyboardShortcut("s", modifiers: [.command, .option])
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

    private func setupRFID() {
        if rfidCoordinator == nil {
            rfidCoordinator = RFIDCoordinator(rfidService: rfidManager)
        }
    }
}
