import Foundation
import SwiftData
import os

/// Manages RapNet inventory sync: upload, price pulls, and scheduled sync.
@MainActor @Observable
final class RapNetSyncService {

    private static let logger = Logger(subsystem: "com.qdi.gemapp", category: "RapNetSync")

    // MARK: - Published state

    var isSyncing = false
    var lastSyncDate: Date? {
        get { UserDefaults.standard.object(forKey: "rapNetLastSyncDate") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "rapNetLastSyncDate") }
    }
    var syncLog: [SyncLogEntry] = []
    var lastError: String?

    // MARK: - Settings (Keychain-backed credentials)

    private static let keychainService = "com.qualitydiajewels.rapnet"
    private static let usernameAccount = "username"
    private static let passwordAccount = "password"

    var username: String {
        get {
            migrateCredentialsIfNeeded()
            return KeychainHelper.load(service: Self.keychainService, account: Self.usernameAccount) ?? ""
        }
        set { KeychainHelper.save(newValue, service: Self.keychainService, account: Self.usernameAccount) }
    }
    var password: String {
        get {
            migrateCredentialsIfNeeded()
            return KeychainHelper.load(service: Self.keychainService, account: Self.passwordAccount) ?? ""
        }
        set { KeychainHelper.save(newValue, service: Self.keychainService, account: Self.passwordAccount) }
    }

    /// One-time migration from UserDefaults to Keychain.
    private func migrateCredentialsIfNeeded() {
        let defaults = UserDefaults.standard
        if let oldUser = defaults.string(forKey: "rapNetUsername"), !oldUser.isEmpty {
            KeychainHelper.save(oldUser, service: Self.keychainService, account: Self.usernameAccount)
            defaults.removeObject(forKey: "rapNetUsername")
        }
        if let oldPass = defaults.string(forKey: "rapNetPassword"), !oldPass.isEmpty {
            KeychainHelper.save(oldPass, service: Self.keychainService, account: Self.passwordAccount)
            defaults.removeObject(forKey: "rapNetPassword")
        }
    }
    var autoSyncEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "rapNetAutoSync") }
        set {
            UserDefaults.standard.set(newValue, forKey: "rapNetAutoSync")
            if newValue { startAutoSync() } else { stopAutoSync() }
        }
    }

    private var token: String?
    private var autoSyncTimer: Timer?

    // MARK: - Sync Log Entry

    struct SyncLogEntry: Identifiable {
        let id = UUID()
        let date: Date
        let action: String
        let status: String
        let detail: String
    }

    // MARK: - Test Connection

    func testConnection() async -> Bool {
        guard !username.isEmpty, !password.isEmpty else {
            lastError = "Username and password are required"
            return false
        }
        do {
            token = try await RapNetAPIService.authenticate(username: username, password: password)
            addLog(action: "Test Connection", status: "Success", detail: "Authenticated successfully")
            lastError = nil
            return true
        } catch {
            lastError = error.localizedDescription
            addLog(action: "Test Connection", status: "Failed", detail: error.localizedDescription)
            return false
        }
    }

    // MARK: - Upload Inventory

    func uploadInventory(modelContext: ModelContext) async {
        var resolvedToken = token
        if resolvedToken == nil {
            resolvedToken = await (try? RapNetAPIService.authenticate(username: username, password: password))
        }
        guard let token = resolvedToken else {
            lastError = "Not authenticated"
            addLog(action: "Upload", status: "Failed", detail: "Authentication failed")
            return
        }
        self.token = token
        isSyncing = true
        lastError = nil

        let availableStatus = GemstoneStatus.available
        let diamondType = StoneType.diamond
        let descriptor = FetchDescriptor<Gemstone>(
            predicate: #Predicate<Gemstone> {
                $0.status == availableStatus && $0.stoneType == diamondType
            }
        )

        do {
            let diamonds = try modelContext.fetch(descriptor)
            guard !diamonds.isEmpty else {
                isSyncing = false
                addLog(action: "Upload", status: "Skipped", detail: "No available diamonds to upload")
                return
            }

            let csv = RapNetExportService.exportDiamondCSV(stones: diamonds)
            let uploadId = try await RapNetAPIService.uploadInventory(csv: csv, token: token)

            // Mark stones as pending
            for stone in diamonds {
                stone.rapNetSyncStatus = .pending
                stone.rapNetLastSynced = Date()
            }
            try modelContext.save()

            addLog(action: "Upload", status: "Success", detail: "\(diamonds.count) diamonds uploaded (ID: \(uploadId))")
            lastSyncDate = Date()
        } catch {
            lastError = error.localizedDescription
            addLog(action: "Upload", status: "Failed", detail: error.localizedDescription)
        }

        isSyncing = false
    }

    // MARK: - Pull Price Sheet

    func pullPriceSheet(modelContext: ModelContext) async {
        var resolvedToken = token
        if resolvedToken == nil {
            resolvedToken = await (try? RapNetAPIService.authenticate(username: username, password: password))
        }
        guard let token = resolvedToken else {
            lastError = "Not authenticated"
            return
        }
        self.token = token
        isSyncing = true

        do {
            let prices = try await RapNetAPIService.fetchPriceList(token: token)

            // Update matching stones with Rapaport prices
            let diamondType = StoneType.diamond
            let descriptor = FetchDescriptor<Gemstone>(
                predicate: #Predicate<Gemstone> { $0.stoneType == diamondType }
            )
            let diamonds = try modelContext.fetch(descriptor)

            var updated = 0
            for priceEntry in prices {
                guard let shape = priceEntry["Shape"] as? String,
                      let color = priceEntry["Color"] as? String,
                      let clarity = priceEntry["Clarity"] as? String,
                      let lowSize = priceEntry["LowSize"] as? Double,
                      let highSize = priceEntry["HighSize"] as? Double,
                      let price = priceEntry["Price"] as? Double else { continue }

                for stone in diamonds {
                    if stone.shape.lowercased() == shape.lowercased()
                        && stone.color.uppercased() == color.uppercased()
                        && stone.clarity.uppercased() == clarity.uppercased()
                        && stone.caratWeight >= lowSize && stone.caratWeight <= highSize {
                        stone.rapNetPrice = Decimal(price)
                        stone.rapNetSyncStatus = .synced
                        updated += 1
                    }
                }
            }

            if updated > 0 { try modelContext.save() }
            addLog(action: "Price Pull", status: "Success", detail: "Updated \(updated) stones from \(prices.count) price entries")
        } catch {
            lastError = error.localizedDescription
            addLog(action: "Price Pull", status: "Failed", detail: error.localizedDescription)
        }

        isSyncing = false
    }

    // MARK: - Auto Sync

    func startAutoSync() {
        stopAutoSync()
        // Sync every 4 hours
        autoSyncTimer = Timer.scheduledTimer(withTimeInterval: 4 * 3600, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let ctx = self.cachedContext else { return }
                await self.uploadInventory(modelContext: ctx)
            }
        }
    }

    func stopAutoSync() {
        autoSyncTimer?.invalidate()
        autoSyncTimer = nil
    }

    /// Set by the view to allow background sync access.
    var cachedContext: ModelContext?

    // MARK: - Helpers

    private func addLog(action: String, status: String, detail: String) {
        let entry = SyncLogEntry(date: Date(), action: action, status: status, detail: detail)
        syncLog.insert(entry, at: 0)
        if syncLog.count > 10 { syncLog.removeLast() }
        Self.logger.info("RapNet \(action): \(status) — \(detail)")
    }
}
