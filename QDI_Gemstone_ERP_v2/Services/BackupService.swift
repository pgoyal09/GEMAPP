import Foundation
import SwiftData

/// Provides backup and export functionality for the gemstone database.
enum BackupService {

    enum BackupError: LocalizedError {
        case noStoreFile
        case exportFailed(String)

        var errorDescription: String? {
            switch self {
            case .noStoreFile:
                return "Database store file not found."
            case .exportFailed(let detail):
                return "Export failed: \(detail)"
            }
        }
    }

    /// The known store URL (must match QDIGemstoneERPApp).
    private static var storeURL: URL {
        URL.applicationSupportDirectory.appending(path: "QDIGemstoneERP_v2.store")
    }

    // MARK: - Temp Cleanup

    /// Removes stale QDI_Backup_* and QDI_CSV_* directories from NSTemporaryDirectory older than 1 hour.
    static func cleanupStaleTempDirs() {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory
        guard let contents = try? fm.contentsOfDirectory(
            at: tempDir, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles
        ) else { return }
        let oneHourAgo = Date().addingTimeInterval(-3600)
        for url in contents {
            let name = url.lastPathComponent
            guard name.hasPrefix("QDI_Backup_") || name.hasPrefix("QDI_CSV_") else { continue }
            if let attrs = try? fm.attributesOfItem(atPath: url.path),
               let created = attrs[.creationDate] as? Date,
               created < oneHourAgo {
                try? fm.removeItem(at: url)
            }
        }
    }

    // MARK: - Database Copy

    /// Copies the SwiftData store file to a temporary location for user export.
    /// Saves the model context first to flush WAL data.
    /// Note: SwiftData does not expose raw SQL, so PRAGMA wal_checkpoint(TRUNCATE) cannot be issued.
    /// The modelContext.save() call flushes pending changes; WAL files are copied alongside the store.
    @MainActor
    static func exportDatabaseCopy(modelContext: ModelContext) throws -> URL {
        cleanupStaleTempDirs()
        try modelContext.save()
        return try copyStoreFiles()
    }

    private static func copyStoreFiles() throws -> URL {
        let fm = FileManager.default
        guard fm.fileExists(atPath: storeURL.path) else {
            throw BackupError.noStoreFile
        }
        let exportDir = fm.temporaryDirectory.appendingPathComponent("QDI_Backup_\(timestamp())")
        try fm.createDirectory(at: exportDir, withIntermediateDirectories: true)

        // Copy main store and WAL/SHM files if present
        let baseName = storeURL.lastPathComponent
        let parentDir = storeURL.deletingLastPathComponent()
        for suffix in ["", "-wal", "-shm"] {
            let sourceURL = parentDir.appendingPathComponent(baseName + suffix)
            if fm.fileExists(atPath: sourceURL.path) {
                try fm.copyItem(at: sourceURL, to: exportDir.appendingPathComponent(baseName + suffix))
            }
        }
        return exportDir
    }

    // MARK: - CSV Export

    /// Exports CSV bundle using a background ModelContext for better performance.
    static func exportCSVBundleInBackground(container: ModelContainer) throws -> URL {
        let bgContext = ModelContext(container)
        bgContext.autosaveEnabled = false
        return try exportCSVBundle(modelContext: bgContext)
    }

    /// Exports gemstones, customers, memos, and invoices to CSV files in a temporary directory.
    @MainActor
    static func exportCSVBundle(modelContext: ModelContext) throws -> URL {
        cleanupStaleTempDirs()
        let fm = FileManager.default
        let exportDir = fm.temporaryDirectory.appendingPathComponent("QDI_CSV_\(timestamp())")
        try fm.createDirectory(at: exportDir, withIntermediateDirectories: true)

        // Gemstones
        let gemstones = try modelContext.fetch(FetchDescriptor<Gemstone>(sortBy: [SortDescriptor(\.sku)]))
        var csv = "SKU,Type,Shape,Grouping,Carat Weight,Color,Clarity,Cut,Cost Price,Sell Price,Status,Origin,Created\n"
        for g in gemstones {
            csv += "\(esc(g.sku)),\(esc(g.stoneType.rawValue)),\(esc(g.shape)),\(esc(g.grouping.rawValue)),\(g.caratWeight),\(esc(g.color)),\(esc(g.clarity)),\(esc(g.cut)),\(g.costPrice),\(g.sellPrice),\(esc(g.status.rawValue)),\(esc(g.origin)),\(g.createdAt.ISO8601Format())\n"
        }
        try csv.write(to: exportDir.appendingPathComponent("gemstones.csv"), atomically: true, encoding: .utf8)

        // Customers
        let customers = try modelContext.fetch(FetchDescriptor<Customer>(sortBy: [SortDescriptor(\.lastName)]))
        csv = "First Name,Last Name,Company,Email,Phone,City,Country\n"
        for c in customers {
            csv += "\(esc(c.firstName)),\(esc(c.lastName)),\(esc(c.company)),\(esc(c.email)),\(esc(c.phone)),\(esc(c.city)),\(esc(c.country))\n"
        }
        try csv.write(to: exportDir.appendingPathComponent("customers.csv"), atomically: true, encoding: .utf8)

        // Memos
        let memos = try modelContext.fetch(FetchDescriptor<Memo>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))
        csv = "Reference,Customer,Status,Date Assigned,Date Completed,Total,Items\n"
        for m in memos {
            let custName = m.customer?.displayName ?? ""
            let dateAssigned = m.dateAssigned?.ISO8601Format() ?? ""
            let dateCompleted = m.dateCompleted?.ISO8601Format() ?? ""
            csv += "\(esc(m.referenceNumber)),\(esc(custName)),\(esc(m.status.rawValue)),\(dateAssigned),\(dateCompleted),\(m.totalAmount),\(m.lineItems.count)\n"
        }
        try csv.write(to: exportDir.appendingPathComponent("memos.csv"), atomically: true, encoding: .utf8)

        // Invoices
        let invoices = try modelContext.fetch(FetchDescriptor<Invoice>(sortBy: [SortDescriptor(\.invoiceDate, order: .reverse)]))
        csv = "Reference,Customer,Status,Date,Due Date,Terms,Total,Items\n"
        for inv in invoices {
            let custName = inv.customer?.displayName ?? ""
            let dueDate = inv.dueDate?.ISO8601Format() ?? ""
            csv += "\(esc(inv.referenceNumber)),\(esc(custName)),\(esc(inv.status.rawValue)),\(inv.invoiceDate.ISO8601Format()),\(dueDate),\(esc(inv.terms)),\(inv.totalAmount),\(inv.lineItems.count)\n"
        }
        try csv.write(to: exportDir.appendingPathComponent("invoices.csv"), atomically: true, encoding: .utf8)

        // Invoice Line Items (per-invoice detail)
        let allLineItems = try modelContext.fetch(FetchDescriptor<LineItem>())
        csv = "Invoice Ref,SKU,Description,Stone Type,Carats,Rate,Amount,Status,Kind\n"
        for item in allLineItems {
            let invoiceRef = item.invoice?.referenceNumber ?? item.memo?.referenceNumber ?? ""
            csv += "\(esc(invoiceRef)),\(esc(item.displaySku)),\(esc(item.displayName)),\(esc(item.stoneTypeDisplay)),\(item.carats),\(item.rate),\(item.amount),\(esc(item.status.rawValue)),\(esc(item.kind.rawValue))\n"
        }
        try csv.write(to: exportDir.appendingPathComponent("line_items.csv"), atomically: true, encoding: .utf8)

        return exportDir
    }

    // MARK: - Helpers

    private static func timestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd_HHmmss"
        return f.string(from: Date())
    }

    /// Escape a CSV field using the shared csvEscaped extension.
    static func esc(_ value: String) -> String {
        value.csvEscaped
    }
}
