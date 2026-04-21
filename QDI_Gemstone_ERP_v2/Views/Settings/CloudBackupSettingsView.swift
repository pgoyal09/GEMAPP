import SwiftUI
import SwiftData

struct CloudBackupSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var backupService = CloudBackupService()
    @State private var backups: [BackupManifest] = []
    @State private var showDeleteConfirm = false
    @State private var showRestoreConfirm = false
    @State private var pendingManifest: BackupManifest?
    @State private var toastMessage: String?
    @State private var toastIsError = false

    private static let sizeFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.allowedUnits = [.useKB, .useMB]
        f.countStyle = .file
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.hero) {
            statusSection
            controlsSection
            backupListSection
        }
        .onAppear { loadBackups() }
        .overlay {
            if let msg = toastMessage {
                ToastOverlay(message: msg, isError: toastIsError)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation(reduceMotion ? nil : .default) { toastMessage = nil }
                        }
                    }
            }
        }
        .alert("Delete Backup?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { pendingManifest = nil }
            Button("Delete", role: .destructive) { performDelete() }
        } message: {
            Text("This backup will be permanently removed.")
        }
        .alert("Restore Backup?", isPresented: $showRestoreConfirm) {
            Button("Cancel", role: .cancel) { pendingManifest = nil }
            Button("Restore", role: .destructive) { performRestore() }
        } message: {
            Text("WARNING: This will replace ALL current data with the backup. This action cannot be undone.")
        }
        .accessibilityIdentifier("CloudBackupSettingsView")
    }

    private func loadBackups() {
        backups = backupService.listBackups(modelContext: modelContext)
    }

    // MARK: - Status

    private var statusSection: some View {
        GlassCard(padding: AppSpacing.hero) {
            VStack(alignment: .leading, spacing: AppSpacing.section) {
                SectionHeader(title: "Cloud Backup Status")

                HStack(spacing: AppSpacing.section) {
                    // iCloud indicator
                    HStack(spacing: AppSpacing.standard) {
                        Image(systemName: backupService.iCloudAvailable ? "icloud.fill" : "icloud.slash")
                            .foregroundStyle(backupService.iCloudAvailable ? AppColors.primary : AppColors.warning)
                        Text(backupService.iCloudAvailable ? "iCloud Drive available" : "iCloud unavailable — using local backup")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.inkMuted)
                    }

                    Spacer()

                    // Encryption indicator
                    HStack(spacing: AppSpacing.standard) {
                        Image(systemName: "lock.shield.fill")
                            .foregroundStyle(AppColors.success)
                        Text("AES-256-GCM encryption")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.inkMuted)
                    }
                }

                if let lastDate = backupService.lastBackupDate {
                    DetailRow(label: "Last Backup", value: lastDate.formatted(date: .abbreviated, time: .shortened))
                } else {
                    DetailRow(label: "Last Backup", value: "Never")
                }

                if backupService.lastBackupWarning {
                    HStack(spacing: AppSpacing.standard) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(AppColors.warning)
                        Text("Last backup is more than 7 days old")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.warning)
                    }
                    .accessibilityLabel("Warning: last backup is older than 7 days")
                }
            }
        }
    }

    // MARK: - Controls

    private var controlsSection: some View {
        GlassCard(padding: AppSpacing.hero) {
            VStack(alignment: .leading, spacing: AppSpacing.section) {
                HStack(spacing: AppSpacing.section) {
                    Button {
                        Task { await backupNow() }
                    } label: {
                        HStack(spacing: AppSpacing.standard) {
                            if backupService.isBackingUp {
                                ProgressView().controlSize(.small)
                            }
                            Text("Backup Now")
                        }
                    }
                    .buttonStyle(.gradient)
                    .disabled(backupService.isBackingUp)
                    .accessibilityLabel("Create cloud backup now")

                    Toggle("Auto-backup (daily)", isOn: Binding(
                        get: { backupService.autoBackupEnabled },
                        set: { backupService.autoBackupEnabled = $0 }
                    ))
                    .toggleStyle(.switch)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.ink)
                    .accessibilityLabel("Enable daily automatic backup")
                }

                if backupService.isBackingUp {
                    VStack(alignment: .leading, spacing: AppSpacing.compact) {
                        Text("Backing up...")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.primary)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: AppCornerRadius.field, style: .continuous)
                                    .fill(AppColors.cardBackground)
                                RoundedRectangle(cornerRadius: AppCornerRadius.field, style: .continuous)
                                    .fill(AppColors.primaryGradient)
                                    .frame(width: geo.size.width * backupService.progress)
                            }
                        }
                        .frame(height: 6)
                    }
                }
            }
        }
    }

    // MARK: - Backup List

    private var backupListSection: some View {
        GlassCard(padding: AppSpacing.hero) {
            VStack(alignment: .leading, spacing: AppSpacing.section) {
                SectionHeader(title: "Backups")

                if backups.isEmpty {
                    Text("No backups yet")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.inkSubtle)
                } else {
                    ForEach(Array(backups.enumerated()), id: \.element.persistentModelID) { index, manifest in
                        HStack(spacing: AppSpacing.comfortable) {
                            Image(systemName: manifest.isEncrypted ? "lock.fill" : "lock.open")
                                .foregroundStyle(manifest.isEncrypted ? AppColors.success : AppColors.warning)
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(manifest.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(AppTypography.body)
                                    .foregroundStyle(AppColors.ink)
                                HStack(spacing: AppSpacing.standard) {
                                    Text(manifest.deviceName)
                                        .font(AppTypography.caption)
                                        .foregroundStyle(AppColors.inkSubtle)
                                    Text("•")
                                        .foregroundStyle(AppColors.inkSubtle)
                                    Text(Self.sizeFormatter.string(fromByteCount: manifest.fileSize))
                                        .font(AppTypography.caption)
                                        .foregroundStyle(AppColors.inkSubtle)
                                    Text("•")
                                        .foregroundStyle(AppColors.inkSubtle)
                                    Text("\(manifest.stoneCount) stones, \(manifest.customerCount) customers")
                                        .font(AppTypography.caption)
                                        .foregroundStyle(AppColors.inkSubtle)
                                }
                            }

                            Spacer()

                            Button("Restore") {
                                pendingManifest = manifest
                                showRestoreConfirm = true
                            }
                            .buttonStyle(.outline)
                            .accessibilityLabel("Restore backup from \(manifest.createdAt.formatted(date: .abbreviated, time: .omitted))")

                            Button {
                                pendingManifest = manifest
                                showDeleteConfirm = true
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(AppColors.danger)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Delete backup")
                        }
                        .padding(.vertical, AppSpacing.standard)
                        .staggeredRow(index: index, reduceMotion: reduceMotion)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Backup from \(manifest.createdAt.formatted(date: .abbreviated, time: .shortened)), \(manifest.stoneCount) stones, \(Self.sizeFormatter.string(fromByteCount: manifest.fileSize))")
                    }
                }

                Text("Backups are encrypted with AES-256-GCM. The encryption key is stored in your Mac's Keychain. If the Keychain key is lost, backups cannot be recovered.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.inkSubtle)
            }
        }
    }

    // MARK: - Actions

    private func backupNow() async {
        await backupService.createBackup(modelContext: modelContext)
        if backupService.lastError == nil {
            toastMessage = "Cloud backup created"
            toastIsError = false
        } else {
            toastMessage = backupService.lastError
            toastIsError = true
        }
        loadBackups()
    }

    private func performDelete() {
        guard let manifest = pendingManifest else { return }
        backupService.deleteBackup(manifest: manifest, modelContext: modelContext)
        pendingManifest = nil
        loadBackups()
        toastMessage = "Backup deleted"
        toastIsError = false
    }

    private func performRestore() {
        guard let manifest = pendingManifest else { return }
        pendingManifest = nil
        Task {
            let success = await backupService.restoreBackup(manifest: manifest, modelContext: modelContext)
            if success {
                toastMessage = "Backup restored — please restart the app"
                toastIsError = false
            } else {
                toastMessage = backupService.lastError ?? "Restore failed"
                toastIsError = true
            }
        }
    }
}
