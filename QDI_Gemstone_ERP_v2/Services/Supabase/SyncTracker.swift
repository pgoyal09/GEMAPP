import Foundation

/// Tracks per-table sync timestamps and dirty record counts.
/// Uses UserDefaults for lightweight persistence.
@MainActor
@Observable
final class SyncTracker {
    static let shared = SyncTracker()

    private let defaults = UserDefaults.standard
    private let prefix = "com.qdi.erp.sync."

    // MARK: - Table Names

    static let allTables = [
        "customers", "gemstones", "memos", "invoices",
        "line_items", "lot_transactions", "payments",
        "history_events", "rfid_tags"
    ]

    // MARK: - Last Sync Timestamps

    func lastSync(for table: String) -> Date? {
        defaults.object(forKey: prefix + table + ".lastSync") as? Date
    }

    func setLastSync(_ date: Date, for table: String) {
        defaults.set(date, forKey: prefix + table + ".lastSync")
    }

    // MARK: - Dirty Count (local changes pending upload)

    var pendingChanges: Int {
        get { defaults.integer(forKey: prefix + "pendingChanges") }
        set { defaults.set(newValue, forKey: prefix + "pendingChanges") }
    }

    func incrementPending() {
        pendingChanges += 1
    }

    func resetPending() {
        pendingChanges = 0
    }

    // MARK: - Full Reset

    func resetAll() {
        for table in Self.allTables {
            defaults.removeObject(forKey: prefix + table + ".lastSync")
        }
        pendingChanges = 0
    }

    // MARK: - Status

    var oldestSync: Date? {
        Self.allTables.compactMap { lastSync(for: $0) }.min()
    }

    var newestSync: Date? {
        Self.allTables.compactMap { lastSync(for: $0) }.max()
    }

    var hasEverSynced: Bool {
        newestSync != nil
    }

    private init() {}
}
