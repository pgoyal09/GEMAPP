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
        isBackingUp = true
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

        isBackingUp = false
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
        isRestoring = true
        lastError = nil
        progress = 0

        do {
            let fileURL = effectiveBackupDir.appendingPathComponent(manifest.iCloudPath)
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                lastError = "Backup file not found"
                isRestoring = false
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

            // Import (would replace local store — for now, save as temp for manual restore)
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("QDI_CloudRestore_\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            try jsonData.write(to: tempDir.appendingPathComponent("backup_data.json"))

            progress = 1.0
            Self.logger.info("Cloud backup restored to: \(tempDir.path)")

            isRestoring = false
            return true
        } catch {
            lastError = error.localizedDescription
            Self.logger.error("Restore failed: \(error.localizedDescription)")
            isRestoring = false
            return false
        }
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
        let stones = try modelContext.fetch(FetchDescriptor<Gemstone>())
        let customers = try modelContext.fetch(FetchDescriptor<Customer>())
        let memos = try modelContext.fetch(FetchDescriptor<Memo>())
        let invoices = try modelContext.fetch(FetchDescriptor<Invoice>())
        let lineItems = try modelContext.fetch(FetchDescriptor<LineItem>())
        let payments = try modelContext.fetch(FetchDescriptor<Payment>())
        let lotTx = try modelContext.fetch(FetchDescriptor<LotTransaction>())
        let rfidTags = try modelContext.fetch(FetchDescriptor<RFIDTag>())

        var exportDict: [String: Any] = [
            "version": 2,
            "exportDate": ISO8601DateFormatter().string(from: Date()),
            "stoneCount": stones.count,
            "customerCount": customers.count,
            "memoCount": memos.count,
            "invoiceCount": invoices.count,
            "lineItemCount": lineItems.count,
            "paymentCount": payments.count,
            "lotTransactionCount": lotTx.count,
            "rfidTagCount": rfidTags.count,
        ]

        // Stone data as array of dicts
        var stoneArray: [[String: Any]] = []
        for s in stones {
            stoneArray.append([
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
                "createdAt": ISO8601DateFormatter().string(from: s.createdAt),
            ])
        }
        exportDict["stones"] = stoneArray

        // Customer data
        var custArray: [[String: Any]] = []
        for c in customers {
            custArray.append([
                "firstName": c.firstName,
                "lastName": c.lastName,
                "company": c.company,
                "email": c.email,
                "phone": c.phone,
                "city": c.city,
                "country": c.country,
            ])
        }
        exportDict["customers"] = custArray

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

enum CloudBackupError: LocalizedError {
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
