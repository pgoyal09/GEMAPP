import Foundation
import SwiftData
import CryptoKit
import os
import Compression

/// Encrypted cloud backup to iCloud Drive.
@MainActor @Observable
final class CloudBackupService {

    private static let logger = Logger(subsystem: "com.qdi.gemapp", category: "CloudBackup")
    private static let keychainTag = "com.qdi.gemapp.v2.backup-key"
    private static let backupFolderName = "QDI_Gemstone_Backups"

    // MARK: - State

    var isBackingUp = false
    var isRestoring = false
    var lastError: String?
    var progress: Double = 0

    var autoBackupEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "cloudAutoBackup") }
        set { UserDefaults.standard.set(newValue, forKey: "cloudAutoBackup") }
    }

    var lastBackupDate: Date? {
        get { UserDefaults.standard.object(forKey: "cloudLastBackupDate") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "cloudLastBackupDate") }
    }

    var lastBackupWarning: Bool {
        guard let last = lastBackupDate else { return true }
        return Date().timeIntervalSince(last) > 7 * 24 * 3600
    }

    // MARK: - iCloud Container

    private var iCloudBackupDir: URL? {
        guard let container = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
            return nil
        }
        let dir = container.appendingPathComponent("Documents/\(Self.backupFolderName)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Fallback directory when iCloud is unavailable — uses Application Support.
    private var localBackupDir: URL {
        let dir = URL.applicationSupportDirectory.appendingPathComponent(Self.backupFolderName)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private var effectiveBackupDir: URL {
        iCloudBackupDir ?? localBackupDir
    }

    var iCloudAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    // MARK: - Create Backup

    func createBackup(modelContext: ModelContext) async {
        guard !isBackingUp && !isRestoring else {
            lastError = "Another backup or restore operation is in progress."
            return
        }
        isBackingUp = true
        defer { isBackingUp = false }
        lastError = nil
        progress = 0

        do {
            // Step 1: Export data as JSON
            progress = 0.1
            let jsonData = try exportJSON(modelContext: modelContext)
            progress = 0.4

            // Step 2: Compress
            let compressed = try compress(jsonData)
            progress = 0.6

            // Step 3: Encrypt
            let key = try getOrCreateEncryptionKey()
            let encrypted = try encrypt(compressed, key: key)
            progress = 0.8

            // Step 4: Write to iCloud Drive / local
            let filename = "backup_\(ISO8601DateFormatter().string(from: Date())).qdibackup"
            let fileURL = effectiveBackupDir.appendingPathComponent(filename)
            try encrypted.write(to: fileURL)

            // Step 5: Record manifest
            let counts = fetchCounts(modelContext: modelContext)
            let manifest = BackupManifest(
                deviceName: Host.current().localizedName ?? "Unknown",
                stoneCount: counts.stones,
                customerCount: counts.customers,
                memoCount: counts.memos,
                invoiceCount: counts.invoices,
                fileSize: Int64(encrypted.count),
                isEncrypted: true,
                iCloudPath: fileURL.lastPathComponent
            )
            modelContext.insert(manifest)
            try modelContext.save()

            lastBackupDate = Date()
            progress = 1.0
            Self.logger.info("Cloud backup created: \(filename) (\(encrypted.count) bytes)")
        } catch {
            lastError = error.localizedDescription
            Self.logger.error("Backup failed: \(error.localizedDescription)")
        }
    }

    // MARK: - List Backups

    func listBackups(modelContext: ModelContext) -> [BackupManifest] {
        let descriptor = FetchDescriptor<BackupManifest>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Restore Backup

    func restoreBackup(manifest: BackupManifest, modelContext: ModelContext) async -> Bool {
        guard !isBackingUp && !isRestoring else {
            lastError = "Another backup or restore operation is in progress."
            return false
        }
        isRestoring = true
        defer { isRestoring = false }
        lastError = nil
        progress = 0

        do {
            let fileURL = effectiveBackupDir.appendingPathComponent(manifest.iCloudPath)
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                lastError = "Backup file not found"
                return false
            }

            progress = 0.2
            let encrypted = try Data(contentsOf: fileURL)

            // Decrypt
            let key = try getEncryptionKey()
            let compressed = try decrypt(encrypted, key: key)
            progress = 0.5

            // Decompress
            let jsonData = try decompress(compressed)
            progress = 0.7

            // Parse and reimport into live SwiftData store.
            // importJSON deletes + inserts in a single modelContext transaction.
            // If import fails, rollback reverts ALL changes (deletes + partial inserts).
            do {
                try importJSON(jsonData, modelContext: modelContext)
            } catch {
                // Rollback: revert deletes + partial inserts so user data is preserved
                modelContext.rollback()
                Self.logger.error("Import failed, rolled back to preserve existing data: \(error.localizedDescription)")
                lastError = "Restore failed: \(error.localizedDescription). Your existing data was preserved."
                return false
            }

            progress = 1.0
            Self.logger.info("Cloud backup restored and reimported into SwiftData")

            return true
        } catch {
            lastError = error.localizedDescription
            Self.logger.error("Restore failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - JSON Import (Restore)

    private func importJSON(_ data: Data, modelContext: ModelContext) throws {
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CloudBackupError.compressionFailed
        }

        let iso = ISO8601DateFormatter()

        // Safety: create a pre-restore backup of current data before destructive delete
        let preRestoreData = try? exportJSON(modelContext: modelContext)
        if let preRestoreData {
            let safetyFilename = "pre_restore_safety_\(ISO8601DateFormatter().string(from: Date())).json"
            let safetyURL = effectiveBackupDir.appendingPathComponent(safetyFilename)
            try? preRestoreData.write(to: safetyURL)
            Self.logger.info("Pre-restore safety backup saved: \(safetyFilename)")
        }

        // Atomic restore: delete all existing data, then reimport.
        // If import fails after delete, attempt to restore from the safety backup.
        // Use modelContext.rollback() if save hasn't been called yet.
        func deleteAll<T: PersistentModel>(_ type: T.Type) throws {
            let items = try modelContext.fetch(FetchDescriptor<T>())
            for item in items { modelContext.delete(item) }
        }
        // Delete in dependency order (children first)
        try deleteAll(HistoryEvent.self)
        try deleteAll(RFIDTag.self)
        try deleteAll(LotTransaction.self)
        try deleteAll(Payment.self)
        try deleteAll(LineItem.self)
        try deleteAll(PaymentReminder.self)
        try deleteAll(ReconciliationRecord.self)
        try deleteAll(Invoice.self)
        try deleteAll(Memo.self)
        try deleteAll(Gemstone.self)
        try deleteAll(Customer.self)
        // Note: we do NOT save here — all deletes + inserts are committed as a single save at the end.
        // If anything fails below, modelContext.rollback() reverts both the deletes and partial inserts.

        // 1. Restore customers — keyed by displayName for relationship linking
        var customerMap: [String: Customer] = [:]
        if let custArray = dict["customers"] as? [[String: Any]] {
            for c in custArray {
                let customer = Customer(
                    firstName: c["firstName"] as? String ?? "",
                    lastName: c["lastName"] as? String ?? "",
                    company: c["company"] as? String ?? "",
                    email: c["email"] as? String ?? "",
                    phone: c["phone"] as? String ?? "",
                    address: c["address"] as? String ?? "",
                    city: c["city"] as? String ?? "",
                    country: c["country"] as? String ?? "",
                    zip: c["zip"] as? String ?? "",
                    notes: c["notes"] as? String ?? ""
                )
                if let dateStr = c["createdAt"] as? String, let d = iso.date(from: dateStr) {
                    customer.createdAt = d
                }
                modelContext.insert(customer)
                customerMap[customer.displayName] = customer
            }
        }

        // 2. Restore stones — keyed by SKU for relationship linking
        var stoneMap: [String: Gemstone] = [:]
        if let stoneArray = dict["stones"] as? [[String: Any]] {
            for s in stoneArray {
                let stoneType = StoneType(rawValue: s["type"] as? String ?? "diamond") ?? .diamond
                let grouping = StoneGrouping(rawValue: s["grouping"] as? String ?? "S") ?? .single
                let status = GemstoneStatus(rawValue: s["status"] as? String ?? "available") ?? .available
                let costStr = s["costPrice"] as? String ?? "0"
                let sellStr = s["sellPrice"] as? String ?? "0"

                let stone = Gemstone(
                    sku: s["sku"] as? String ?? "",
                    stoneType: stoneType,
                    caratWeight: s["caratWeight"] as? Double ?? 0,
                    shape: s["shape"] as? String ?? "",
                    grouping: grouping,
                    origin: s["origin"] as? String ?? "",
                    status: status,
                    color: s["color"] as? String ?? "",
                    clarity: s["clarity"] as? String ?? "",
                    cut: s["cut"] as? String ?? "",
                    costPrice: Decimal(string: costStr) ?? 0,
                    sellPrice: Decimal(string: sellStr) ?? 0
                )
                if let dateStr = s["createdAt"] as? String, let d = iso.date(from: dateStr) {
                    stone.createdAt = d
                }
                if let rc = s["remainingCarats"] as? Double { stone.remainingCarats = rc }
                if let acStr = s["averageCostPerCarat"] as? String {
                    stone.averageCostPerCarat = Decimal(string: acStr)
                }
                modelContext.insert(stone)
                stoneMap[stone.sku] = stone
            }
        }

        // 3. Restore memos — keyed by referenceNumber
        var memoMap: [String: Memo] = [:]
        if let memoArray = dict["memos"] as? [[String: Any]] {
            for m in memoArray {
                let statusVal = MemoStatus(rawValue: m["status"] as? String ?? "On Memo") ?? .onMemo
                let memo = Memo(
                    status: statusVal,
                    notes: m["notes"] as? String ?? "",
                    referenceNumber: m["referenceNumber"] as? String ?? "",
                    salesperson: m["salesperson"] as? String
                )
                if let dateStr = m["createdAt"] as? String, let d = iso.date(from: dateStr) {
                    memo.createdAt = d
                }
                if let dateStr = m["dateAssigned"] as? String, let d = iso.date(from: dateStr) {
                    memo.dateAssigned = d
                }
                if let dateStr = m["dateCompleted"] as? String, let d = iso.date(from: dateStr) {
                    memo.dateCompleted = d
                }
                if let custName = m["customerName"] as? String {
                    memo.customer = customerMap[custName]
                }
                modelContext.insert(memo)
                memoMap[memo.referenceNumber] = memo
            }
        }

        // 4. Restore invoices — keyed by referenceNumber
        var invoiceMap: [String: Invoice] = [:]
        if let invArray = dict["invoices"] as? [[String: Any]] {
            for inv in invArray {
                let statusVal = InvoiceStatus(rawValue: inv["status"] as? String ?? "Sent") ?? .sent
                let invoice = Invoice(
                    terms: inv["terms"] as? String ?? "Net 30",
                    referenceNumber: inv["referenceNumber"] as? String ?? "",
                    notes: inv["notes"] as? String ?? "",
                    status: statusVal,
                    discountAmount: Decimal(string: inv["discountAmount"] as? String ?? "0") ?? 0,
                    taxRate: Decimal(string: inv["taxRate"] as? String ?? "0") ?? 0,
                    salesperson: inv["salesperson"] as? String
                )
                if let dateStr = inv["invoiceDate"] as? String, let d = iso.date(from: dateStr) {
                    invoice.invoiceDate = d
                }
                if let dateStr = inv["dueDate"] as? String, let d = iso.date(from: dateStr) {
                    invoice.dueDate = d
                }
                if let dateStr = inv["createdAt"] as? String, let d = iso.date(from: dateStr) {
                    invoice.createdAt = d
                }
                if let custName = inv["customerName"] as? String {
                    invoice.customer = customerMap[custName]
                }
                if let memoRef = inv["originMemoRef"] as? String {
                    invoice.originMemo = memoMap[memoRef]
                }
                modelContext.insert(invoice)
                invoiceMap[invoice.referenceNumber] = invoice
            }
        }

        // 5. Restore line items
        if let liArray = dict["lineItems"] as? [[String: Any]] {
            for li in liArray {
                let kind = LineItemKind(rawValue: li["kind"] as? String ?? "Inventory") ?? .inventory
                let status = LineItemStatus(rawValue: li["status"] as? String ?? "Open") ?? .open
                let item = LineItem(
                    sku: li["sku"] as? String ?? "",
                    itemDescription: li["itemDescription"] as? String ?? "",
                    carats: li["carats"] as? Double ?? 0,
                    rate: Decimal(string: li["rate"] as? String ?? "0") ?? 0,
                    amount: Decimal(string: li["amount"] as? String ?? "0") ?? 0,
                    kind: kind,
                    status: status,
                    discount: Decimal(string: li["discount"] as? String ?? "0") ?? 0,
                    brokeredStoneType: li["brokeredStoneType"] as? String ?? "",
                    isLotLineItem: li["isLotLineItem"] as? Bool ?? false,
                    lockedCostPerCarat: (li["lockedCostPerCarat"] as? String).flatMap { Decimal(string: $0) }
                )
                if let dateStr = li["returnedDate"] as? String, let d = iso.date(from: dateStr) {
                    item.returnedDate = d
                }
                if let dateStr = li["soldDate"] as? String, let d = iso.date(from: dateStr) {
                    item.soldDate = d
                }
                if let sku = li["gemstoneSku"] as? String { item.gemstone = stoneMap[sku] }
                if let ref = li["invoiceRef"] as? String { item.invoice = invoiceMap[ref] }
                if let ref = li["memoRef"] as? String { item.memo = memoMap[ref] }
                modelContext.insert(item)
            }
        }

        // 6. Restore payments
        if let payArray = dict["payments"] as? [[String: Any]] {
            for p in payArray {
                let method = PaymentMethod(rawValue: p["method"] as? String ?? "Wire") ?? .wire
                let payment = Payment(
                    amount: Decimal(string: p["amount"] as? String ?? "0") ?? 0,
                    method: method,
                    referenceNumber: p["referenceNumber"] as? String ?? ""
                )
                if let dateStr = p["date"] as? String, let d = iso.date(from: dateStr) {
                    payment.date = d
                }
                if let ref = p["invoiceRef"] as? String { payment.invoice = invoiceMap[ref] }
                modelContext.insert(payment)
            }
        }

        // 7. Restore lot transactions
        if let ltArray = dict["lotTransactions"] as? [[String: Any]] {
            for lt in ltArray {
                let type = LotTransactionType(rawValue: lt["type"] as? String ?? "Added") ?? .added
                let tx = LotTransaction(
                    type: type,
                    carats: lt["carats"] as? Double ?? 0,
                    pricePerCarat: Decimal(string: lt["pricePerCarat"] as? String ?? "0") ?? 0,
                    totalPrice: Decimal(string: lt["totalPrice"] as? String ?? "0") ?? 0,
                    lockedCostPerCarat: (lt["lockedCostPerCarat"] as? String).flatMap { Decimal(string: $0) },
                    notes: lt["notes"] as? String ?? ""
                )
                if let dateStr = lt["date"] as? String, let d = iso.date(from: dateStr) {
                    tx.date = d
                }
                if let sku = lt["gemstoneSku"] as? String { tx.gemstone = stoneMap[sku] }
                modelContext.insert(tx)
            }
        }

        // 8. Restore RFID tags
        if let rfidArray = dict["rfidTags"] as? [[String: Any]] {
            for r in rfidArray {
                let status = RFIDLifecycleStatus(rawValue: r["status"] as? String ?? "unassigned") ?? .unassigned
                let tag = RFIDTag(
                    epcCurrent: r["epcCurrent"] as? String ?? "",
                    tidLastVerified: r["tidLastVerified"] as? String,
                    status: status,
                    printerJobID: r["printerJobID"] as? String,
                    notes: r["notes"] as? String
                )
                if let dateStr = r["firstSeenAt"] as? String, let d = iso.date(from: dateStr) {
                    tag.firstSeenAt = d
                }
                if let dateStr = r["lastSeenAt"] as? String, let d = iso.date(from: dateStr) {
                    tag.lastSeenAt = d
                }
                if let dateStr = r["lastVerifiedAt"] as? String, let d = iso.date(from: dateStr) {
                    tag.lastVerifiedAt = d
                }
                if let sku = r["assignedStoneSku"] as? String { tag.assignedStone = stoneMap[sku] }
                modelContext.insert(tag)
            }
        }

        // 9. Restore history events
        if let evArray = dict["historyEvents"] as? [[String: Any]] {
            for e in evArray {
                let type = HistoryEventType(rawValue: e["eventType"] as? String ?? "Date Added") ?? .dateAdded
                let event = HistoryEvent(
                    eventDescription: e["eventDescription"] as? String ?? "",
                    eventType: type
                )
                if let dateStr = e["date"] as? String, let d = iso.date(from: dateStr) {
                    event.date = d
                }
                if let sku = e["gemstoneSku"] as? String { event.gemstone = stoneMap[sku] }
                modelContext.insert(event)
            }
        }

        // 10. Restore reconciliation records
        if let recArray = dict["reconciliationRecords"] as? [[String: Any]] {
            for r in recArray {
                let record = ReconciliationRecord(
                    matchedCount: r["matchedCount"] as? Int ?? 0,
                    missingCount: r["missingCount"] as? Int ?? 0,
                    unknownCount: r["unknownCount"] as? Int ?? 0,
                    missingSkus: r["missingSkus"] as? String ?? ""
                )
                if let dateStr = r["date"] as? String, let d = iso.date(from: dateStr) {
                    record.date = d
                }
                modelContext.insert(record)
            }
        }

        // 11. Restore payment reminders
        if let prArray = dict["paymentReminders"] as? [[String: Any]] {
            for pr in prArray {
                let reminder = PaymentReminder(
                    customerName: pr["customerName"] as? String ?? "",
                    invoiceReferences: pr["invoiceReferences"] as? String ?? "",
                    amount: Decimal(string: pr["amount"] as? String ?? "0") ?? 0,
                    method: pr["method"] as? String ?? "memo"
                )
                reminder.sent = pr["sent"] as? Bool ?? false
                if let dateStr = pr["date"] as? String, let d = iso.date(from: dateStr) {
                    reminder.date = d
                }
                if let dateStr = pr["createdAt"] as? String, let d = iso.date(from: dateStr) {
                    reminder.createdAt = d
                }
                modelContext.insert(reminder)
            }
        }

        try modelContext.save()
    }

    // MARK: - Delete Backup

    func deleteBackup(manifest: BackupManifest, modelContext: ModelContext) {
        let fileURL = effectiveBackupDir.appendingPathComponent(manifest.iCloudPath)
        try? FileManager.default.removeItem(at: fileURL)
        modelContext.delete(manifest)
        try? modelContext.save()
    }

    // MARK: - Scheduled Backup

    func scheduleAutoBackup(modelContext: ModelContext) {
        guard autoBackupEnabled else { return }
        // Check if it's been > 24 hours since last backup
        if let last = lastBackupDate, Date().timeIntervalSince(last) < 24 * 3600 {
            return
        }
        Task {
            await createBackup(modelContext: modelContext)
        }
    }

    // MARK: - JSON Export

    private func exportJSON(modelContext: ModelContext) throws -> Data {
        let iso = ISO8601DateFormatter()
        let stones = try modelContext.fetch(FetchDescriptor<Gemstone>())
        let customers = try modelContext.fetch(FetchDescriptor<Customer>())
        let memos = try modelContext.fetch(FetchDescriptor<Memo>())
        let invoices = try modelContext.fetch(FetchDescriptor<Invoice>())
        let lineItems = try modelContext.fetch(FetchDescriptor<LineItem>())
        let payments = try modelContext.fetch(FetchDescriptor<Payment>())
        let lotTx = try modelContext.fetch(FetchDescriptor<LotTransaction>())
        let rfidTags = try modelContext.fetch(FetchDescriptor<RFIDTag>())
        let historyEvents = try modelContext.fetch(FetchDescriptor<HistoryEvent>())
        let reconciliationRecords = try modelContext.fetch(FetchDescriptor<ReconciliationRecord>())
        let paymentReminders = try modelContext.fetch(FetchDescriptor<PaymentReminder>())

        var exportDict: [String: Any] = [
            "version": 2,
            "exportDate": iso.string(from: Date()),
            "stoneCount": stones.count,
            "customerCount": customers.count,
            "memoCount": memos.count,
            "invoiceCount": invoices.count,
            "lineItemCount": lineItems.count,
            "paymentCount": payments.count,
            "lotTransactionCount": lotTx.count,
            "rfidTagCount": rfidTags.count,
        ]

        // Customer data
        var custArray: [[String: Any]] = []
        for c in customers {
            custArray.append([
                "firstName": c.firstName,
                "lastName": c.lastName,
                "company": c.company,
                "email": c.email,
                "phone": c.phone,
                "address": c.address,
                "city": c.city,
                "country": c.country,
                "zip": c.zip,
                "notes": c.notes,
                "createdAt": iso.string(from: c.createdAt),
            ])
        }
        exportDict["customers"] = custArray

        // Stone data
        var stoneArray: [[String: Any]] = []
        for s in stones {
            var dict: [String: Any] = [
                "sku": s.sku,
                "type": s.stoneType.rawValue,
                "shape": s.shape,
                "grouping": s.grouping.rawValue,
                "caratWeight": s.caratWeight,
                "color": s.color,
                "clarity": s.clarity,
                "cut": s.cut,
                "costPrice": "\(s.costPrice)",
                "sellPrice": "\(s.sellPrice)",
                "status": s.status.rawValue,
                "origin": s.origin,
                "createdAt": iso.string(from: s.createdAt),
            ]
            if let rc = s.remainingCarats { dict["remainingCarats"] = rc }
            if let ac = s.averageCostPerCarat { dict["averageCostPerCarat"] = "\(ac)" }
            stoneArray.append(dict)
        }
        exportDict["stones"] = stoneArray

        // Memo data
        var memoArray: [[String: Any]] = []
        for m in memos {
            var dict: [String: Any] = [
                "referenceNumber": m.referenceNumber,
                "status": m.status.rawValue,
                "notes": m.notes,
                "createdAt": iso.string(from: m.createdAt),
            ]
            if let d = m.dateAssigned { dict["dateAssigned"] = iso.string(from: d) }
            if let d = m.dateCompleted { dict["dateCompleted"] = iso.string(from: d) }
            if let sp = m.salesperson { dict["salesperson"] = sp }
            if let cust = m.customer { dict["customerName"] = cust.displayName }
            memoArray.append(dict)
        }
        exportDict["memos"] = memoArray

        // Invoice data
        var invArray: [[String: Any]] = []
        for inv in invoices {
            var dict: [String: Any] = [
                "referenceNumber": inv.referenceNumber,
                "invoiceDate": iso.string(from: inv.invoiceDate),
                "terms": inv.terms,
                "notes": inv.notes,
                "createdAt": iso.string(from: inv.createdAt),
                "status": inv.status.rawValue,
                "discountAmount": "\(inv.discountAmount)",
                "taxRate": "\(inv.taxRate)",
            ]
            if let d = inv.dueDate { dict["dueDate"] = iso.string(from: d) }
            if let sp = inv.salesperson { dict["salesperson"] = sp }
            if let cust = inv.customer { dict["customerName"] = cust.displayName }
            if let om = inv.originMemo { dict["originMemoRef"] = om.referenceNumber }
            invArray.append(dict)
        }
        exportDict["invoices"] = invArray

        // Line item data
        var liArray: [[String: Any]] = []
        for li in lineItems {
            var dict: [String: Any] = [
                "sku": li.sku,
                "itemDescription": li.itemDescription,
                "carats": li.carats,
                "rate": "\(li.rate)",
                "amount": "\(li.amount)",
                "kind": li.kind.rawValue,
                "status": li.status.rawValue,
                "discount": "\(li.discount)",
                "brokeredStoneType": li.brokeredStoneType,
                "isLotLineItem": li.isLotLineItem,
            ]
            if let lc = li.lockedCostPerCarat { dict["lockedCostPerCarat"] = "\(lc)" }
            if let d = li.returnedDate { dict["returnedDate"] = iso.string(from: d) }
            if let d = li.soldDate { dict["soldDate"] = iso.string(from: d) }
            if let g = li.gemstone { dict["gemstoneSku"] = g.sku }
            if let inv = li.invoice { dict["invoiceRef"] = inv.referenceNumber }
            if let m = li.memo { dict["memoRef"] = m.referenceNumber }
            liArray.append(dict)
        }
        exportDict["lineItems"] = liArray

        // Payment data
        var payArray: [[String: Any]] = []
        for p in payments {
            var dict: [String: Any] = [
                "date": iso.string(from: p.date),
                "amount": "\(p.amount)",
                "method": p.method.rawValue,
                "referenceNumber": p.referenceNumber,
            ]
            if let inv = p.invoice { dict["invoiceRef"] = inv.referenceNumber }
            payArray.append(dict)
        }
        exportDict["payments"] = payArray

        // Lot transaction data
        var ltArray: [[String: Any]] = []
        for lt in lotTx {
            var dict: [String: Any] = [
                "type": lt.type.rawValue,
                "carats": lt.carats,
                "date": iso.string(from: lt.date),
                "pricePerCarat": "\(lt.pricePerCarat)",
                "totalPrice": "\(lt.totalPrice)",
                "notes": lt.notes,
            ]
            if let lc = lt.lockedCostPerCarat { dict["lockedCostPerCarat"] = "\(lc)" }
            if let g = lt.gemstone { dict["gemstoneSku"] = g.sku }
            ltArray.append(dict)
        }
        exportDict["lotTransactions"] = ltArray

        // RFID tag data
        var rfidArray: [[String: Any]] = []
        for r in rfidTags {
            var dict: [String: Any] = [
                "epcCurrent": r.epcCurrent,
                "status": r.status.rawValue,
            ]
            if let t = r.tidLastVerified { dict["tidLastVerified"] = t }
            if let d = r.firstSeenAt { dict["firstSeenAt"] = iso.string(from: d) }
            if let d = r.lastSeenAt { dict["lastSeenAt"] = iso.string(from: d) }
            if let d = r.lastVerifiedAt { dict["lastVerifiedAt"] = iso.string(from: d) }
            if let j = r.printerJobID { dict["printerJobID"] = j }
            if let n = r.notes { dict["notes"] = n }
            if let g = r.assignedStone { dict["assignedStoneSku"] = g.sku }
            rfidArray.append(dict)
        }
        exportDict["rfidTags"] = rfidArray

        // History event data
        var evArray: [[String: Any]] = []
        for e in historyEvents {
            var dict: [String: Any] = [
                "date": iso.string(from: e.date),
                "eventDescription": e.eventDescription,
                "eventType": e.eventType.rawValue,
            ]
            if let g = e.gemstone { dict["gemstoneSku"] = g.sku }
            evArray.append(dict)
        }
        exportDict["historyEvents"] = evArray

        // Reconciliation record data
        var recArray: [[String: Any]] = []
        for r in reconciliationRecords {
            recArray.append([
                "date": iso.string(from: r.date),
                "matchedCount": r.matchedCount,
                "missingCount": r.missingCount,
                "unknownCount": r.unknownCount,
                "missingSkus": r.missingSkus,
            ])
        }
        exportDict["reconciliationRecords"] = recArray

        // Payment reminder data
        var prArray: [[String: Any]] = []
        for pr in paymentReminders {
            prArray.append([
                "date": iso.string(from: pr.date),
                "customerName": pr.customerName,
                "invoiceReferences": pr.invoiceReferences,
                "amount": "\(pr.amount)",
                "sent": pr.sent,
                "method": pr.method,
                "createdAt": iso.string(from: pr.createdAt),
            ])
        }
        exportDict["paymentReminders"] = prArray

        return try JSONSerialization.data(withJSONObject: exportDict, options: [.prettyPrinted, .sortedKeys])
    }

    // MARK: - Counts

    private func fetchCounts(modelContext: ModelContext) -> (stones: Int, customers: Int, memos: Int, invoices: Int) {
        let stones = (try? modelContext.fetchCount(FetchDescriptor<Gemstone>())) ?? 0
        let customers = (try? modelContext.fetchCount(FetchDescriptor<Customer>())) ?? 0
        let memos = (try? modelContext.fetchCount(FetchDescriptor<Memo>())) ?? 0
        let invoices = (try? modelContext.fetchCount(FetchDescriptor<Invoice>())) ?? 0
        return (stones, customers, memos, invoices)
    }

    // MARK: - Encryption (AES-256-GCM via CryptoKit)

    private func getOrCreateEncryptionKey() throws -> SymmetricKey {
        if let existing = try? getEncryptionKey() {
            return existing
        }
        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data($0) }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainTag,
            kSecAttrAccount as String: "backup-encryption-key",
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw CloudBackupError.keychainError("Failed to store key: \(status)")
        }
        return key
    }

    private func getEncryptionKey() throws -> SymmetricKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainTag,
            kSecAttrAccount as String: "backup-encryption-key",
            kSecReturnData as String: true,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            throw CloudBackupError.noEncryptionKey
        }
        return SymmetricKey(data: data)
    }

    private func encrypt(_ data: Data, key: SymmetricKey) throws -> Data {
        let sealed = try AES.GCM.seal(data, using: key)
        guard let combined = sealed.combined else {
            throw CloudBackupError.encryptionFailed
        }
        return combined
    }

    private func decrypt(_ data: Data, key: SymmetricKey) throws -> Data {
        let box = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(box, using: key)
    }

    // MARK: - Compression

    private func compress(_ data: Data) throws -> Data {
        let sourceSize = data.count
        let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: sourceSize)
        defer { destinationBuffer.deallocate() }

        let compressedSize = data.withUnsafeBytes { sourceBuffer -> Int in
            guard let baseAddress = sourceBuffer.baseAddress else { return 0 }
            return compression_encode_buffer(
                destinationBuffer, sourceSize,
                baseAddress.assumingMemoryBound(to: UInt8.self), sourceSize,
                nil, COMPRESSION_ZLIB
            )
        }

        guard compressedSize > 0 else {
            throw CloudBackupError.compressionFailed
        }

        // Prefix with original size (8 bytes, little-endian) for decompression
        var size = UInt64(sourceSize).littleEndian
        var result = Data(bytes: &size, count: 8)
        result.append(Data(bytes: destinationBuffer, count: compressedSize))
        return result
    }

    private func decompress(_ data: Data) throws -> Data {
        guard data.count > 8 else { throw CloudBackupError.compressionFailed }

        let originalSize: Int = data.withUnsafeBytes { buf in
            let size = buf.loadUnaligned(as: UInt64.self)
            return Int(UInt64(littleEndian: size))
        }

        let compressedData = data.dropFirst(8)
        let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: originalSize)
        defer { destinationBuffer.deallocate() }

        let decompressedSize = compressedData.withUnsafeBytes { sourceBuffer -> Int in
            guard let baseAddress = sourceBuffer.baseAddress else { return 0 }
            return compression_decode_buffer(
                destinationBuffer, originalSize,
                baseAddress.assumingMemoryBound(to: UInt8.self), compressedData.count,
                nil, COMPRESSION_ZLIB
            )
        }

        guard decompressedSize > 0 else {
            throw CloudBackupError.compressionFailed
        }

        return Data(bytes: destinationBuffer, count: decompressedSize)
    }
}

// MARK: - Errors

enum CloudBackupError: LocalizedError, Sendable {
    case noEncryptionKey
    case encryptionFailed
    case compressionFailed
    case keychainError(String)
    case iCloudUnavailable

    var errorDescription: String? {
        switch self {
        case .noEncryptionKey:
            return "Encryption key not found in Keychain. Backup cannot be decrypted."
        case .encryptionFailed:
            return "Encryption failed."
        case .compressionFailed:
            return "Data compression/decompression failed."
        case .keychainError(let msg):
            return "Keychain error: \(msg)"
        case .iCloudUnavailable:
            return "iCloud Drive is not available. Sign in to iCloud in System Settings."
        }
    }
}
