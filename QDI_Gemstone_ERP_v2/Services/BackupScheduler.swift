import Foundation
import SwiftData

/// Automatic scheduled backup service.
/// Runs a Timer at a configurable interval (default 24h) and saves
/// the database to a user-chosen directory.
@MainActor
@Observable
final class BackupScheduler {
    private var timer: Timer?
    private var modelContainer: ModelContainer?
    private var isPerformingBackup = false
    /// Last auto-backup error, displayed in dashboard info panel
    var lastBackupError: String?

    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "autoBackupEnabled") }
        set {
            UserDefaults.standard.set(newValue, forKey: "autoBackupEnabled")
            if newValue { startTimer() } else { stopTimer() }
        }
    }

    var intervalHours: Int {
        get {
            let stored = UserDefaults.standard.integer(forKey: "autoBackupIntervalHours")
            return stored > 0 ? stored : 24
        }
        set {
            UserDefaults.standard.set(max(1, newValue), forKey: "autoBackupIntervalHours")
            if isEnabled { startTimer() }
        }
    }

    var backupDirectory: URL? {
        get {
            guard let path = UserDefaults.standard.string(forKey: "autoBackupDirectory") else { return nil }
            return URL(fileURLWithPath: path)
        }
        set {
            UserDefaults.standard.set(newValue?.path, forKey: "autoBackupDirectory")
        }
    }

    var lastBackupDate: Date? {
        get { UserDefaults.standard.object(forKey: "autoBackupLastDate") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "autoBackupLastDate") }
    }

    var lastBackupAgo: String {
        guard let date = lastBackupDate else { return "Never" }
        let hours = Int(-date.timeIntervalSinceNow / 3600)
        if hours < 1 { return "< 1 hour ago" }
        if hours == 1 { return "1 hour ago" }
        return "\(hours) hours ago"
    }

    func configure(container: ModelContainer) {
        self.modelContainer = container
        if isEnabled { startTimer() }
    }

    func performBackupNow() {
        guard let container = modelContainer, let dir = backupDirectory else {
            AppLogger.backup.warning("Auto-backup skipped: container or directory not configured")
            return
        }
        guard !isPerformingBackup else {
            AppLogger.backup.info("Auto-backup skipped: already in progress")
            return
        }
        isPerformingBackup = true
        AppLogger.backup.info("Auto-backup started to: \(dir.lastPathComponent, privacy: .public)")
        Task { [weak self] in
            do {
                // SwiftData operations must be on MainActor
                let exportDir = try await MainActor.run {
                    let ctx = container.mainContext
                    try ctx.save()
                    return try BackupService.exportDatabaseCopy(modelContext: ctx)
                }
                // File copy operations run off MainActor to avoid blocking UI
                let fm = FileManager.default
                let ts = await MainActor.run { self?.timestamp() ?? "" }
                let destDir = dir.appendingPathComponent("QDI_AutoBackup_\(ts)")
                if fm.fileExists(atPath: destDir.path) { try fm.removeItem(at: destDir) }
                try fm.copyItem(at: exportDir, to: destDir)
                try fm.removeItem(at: exportDir)
                await MainActor.run {
                    self?.lastBackupDate = Date()
                    self?.lastBackupError = nil
                    self?.isPerformingBackup = false
                }
                AppLogger.backup.info("Auto-backup completed: \(destDir.lastPathComponent, privacy: .public)")
            } catch {
                await MainActor.run {
                    self?.lastBackupError = "Auto-backup failed: \(error.localizedDescription)"
                    self?.isPerformingBackup = false
                }
                AppLogger.backup.error("Auto-backup failed: \(error.localizedDescription)")
            }
        }
    }

    private func startTimer() {
        stopTimer()
        let interval = TimeInterval(intervalHours * 3600)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.performBackupNow()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func timestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd_HHmmss"
        return f.string(from: Date())
    }
}
