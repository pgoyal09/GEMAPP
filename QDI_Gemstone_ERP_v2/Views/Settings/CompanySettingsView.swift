import SwiftUI
import SwiftData
import AppKit

struct CompanySettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("companyName") private var companyName: String = ""
    @AppStorage("companyAddress") private var companyAddress: String = ""
    @AppStorage("companyPhone") private var companyPhone: String = ""
    @AppStorage("companyEmail") private var companyEmail: String = ""
    @State private var logoData: Data? = UserDefaults.standard.data(forKey: PDFService.companyLogoUserDefaultsKey)
    @State private var showSavedToast = false
    @AppStorage("appAppearance") private var appAppearance: String = "dark"
    @AppStorage("memoAgingGreen") private var memoAgingGreen: Int = 7
    @AppStorage("memoAgingYellow") private var memoAgingYellow: Int = 14
    @AppStorage("memoAgingOrange") private var memoAgingOrange: Int = 30
    @State private var backupMessage: String?
    @State private var backupIsError = false
    @State private var showRestoreConfirm = false
    @State private var pendingRestoreURL: URL?
    @State private var backupScheduler = BackupScheduler()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SectionHeader(title: "Company Branding")

                VStack(alignment: .leading, spacing: 16) {
                    fieldRow(label: "Company Name") {
                        TextField("e.g. Quality Diajewels Inc.", text: $companyName)
                            .textFieldStyle(.roundedBorder)
                    }

                    fieldRow(label: "Address") {
                        TextEditor(text: $companyAddress)
                            .font(.body)
                            .frame(height: 60)
                            .padding(4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white.opacity(0.05))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                                    )
                            )
                            .scrollContentBackground(.hidden)
                    }

                    fieldRow(label: "Phone") {
                        TextField("e.g. +1 212-555-0100", text: $companyPhone)
                            .textFieldStyle(.roundedBorder)
                    }

                    fieldRow(label: "Email") {
                        TextField("e.g. info@company.com", text: $companyEmail)
                            .textFieldStyle(.roundedBorder)
                    }

                    fieldRow(label: "Logo") {
                        HStack(spacing: 12) {
                            if let data = logoData, let nsImage = NSImage(data: data) {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 56)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))

                                Button("Remove") {
                                    logoData = nil
                                    UserDefaults.standard.removeObject(forKey: PDFService.companyLogoUserDefaultsKey)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(AppColors.danger)
                                .font(AppTypography.caption)
                            }

                            Button("Choose Image…") { pickLogo() }
                                .buttonStyle(.outline)
                        }
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: AppCornerRadius.m, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppCornerRadius.m, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
                        )
                )

                if showSavedToast {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppColors.success)
                        Text("Settings saved automatically")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.inkMuted)
                    }
                    .transition(.opacity)
                }

                // MARK: - Appearance

                SectionHeader(title: "Appearance")

                VStack(alignment: .leading, spacing: 12) {
                    Picker("Theme", selection: $appAppearance) {
                        Text("Dark").tag("dark")
                        Text("Light").tag("light")
                        Text("System").tag("system")
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 300)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: AppCornerRadius.m, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppCornerRadius.m, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
                        )
                )

                // MARK: - Memo Aging Thresholds

                SectionHeader(title: "Memo Aging Alerts")

                VStack(alignment: .leading, spacing: 12) {
                    agingRow(label: "Green → Yellow (days)", value: $memoAgingGreen)
                    agingRow(label: "Yellow → Orange (days)", value: $memoAgingYellow)
                    agingRow(label: "Orange → Red (days)", value: $memoAgingOrange)
                    Text("Memos are color-coded by age on the dashboard.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.inkSubtle)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: AppCornerRadius.m, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppCornerRadius.m, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
                        )
                )

                Text("These details appear on generated PDF invoices and memos.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.inkSubtle)

                // MARK: - Auto Backup

                SectionHeader(title: "Automatic Backup")

                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Enable scheduled backups", isOn: $backupScheduler.isEnabled)
                        .toggleStyle(.checkbox)

                    if backupScheduler.isEnabled {
                        HStack(spacing: 12) {
                            Text("Interval (hours)")
                                .font(AppTypography.body)
                                .foregroundStyle(AppColors.inkMuted)
                            TextField("", value: $backupScheduler.intervalHours, format: .number)
                                .frame(width: 60)
                                .textFieldStyle(.roundedBorder)
                                .multilineTextAlignment(.center)
                        }

                        HStack(spacing: 12) {
                            Text("Backup folder")
                                .font(AppTypography.body)
                                .foregroundStyle(AppColors.inkMuted)
                            Text(backupScheduler.backupDirectory?.path ?? "Not set")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.inkSubtle)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Button("Choose…") { pickBackupDirectory() }
                                .buttonStyle(.outline)
                        }

                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .font(.system(size: 11))
                                .foregroundStyle(AppColors.inkSubtle)
                            Text("Last backup: \(backupScheduler.lastBackupAgo)")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.inkMuted)
                            Spacer()
                            Button("Backup Now") { backupScheduler.performBackupNow() }
                                .buttonStyle(.outline)
                                .disabled(backupScheduler.backupDirectory == nil)
                        }
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: AppCornerRadius.m, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppCornerRadius.m, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
                        )
                )

                // MARK: - Backup & Export

                SectionHeader(title: "Backup & Export")

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Button("Export CSV Bundle…") { exportCSV() }
                            .buttonStyle(.outline)
                        Button("Export Database Copy…") { exportDatabase() }
                            .buttonStyle(.outline)
                        Button("Restore from Backup…") { pickBackupToRestore() }
                            .buttonStyle(.outline(AppColors.warning))
                    }

                    if let msg = backupMessage {
                        HStack(spacing: 6) {
                            Image(systemName: backupIsError ? "xmark.circle.fill" : "checkmark.circle.fill")
                                .foregroundStyle(backupIsError ? AppColors.danger : AppColors.success)
                            Text(msg)
                                .font(AppTypography.caption)
                                .foregroundStyle(backupIsError ? AppColors.danger : AppColors.inkMuted)
                        }
                    }

                    Text("CSV exports gemstones, customers, memos, and invoices as separate CSV files. Database copy exports the raw SwiftData store. Restore replaces all current data with a previous backup.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.inkSubtle)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: AppCornerRadius.m, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppCornerRadius.m, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
                        )
                )

                Spacer()
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("CompanySettingsView")
        .alert("Restore from Backup?", isPresented: $showRestoreConfirm) {
            Button("Cancel", role: .cancel) { pendingRestoreURL = nil }
            Button("Replace All Data", role: .destructive) { performRestore() }
        } message: {
            Text("This will replace ALL current data with the backup. This action cannot be undone. The app will quit and must be relaunched.")
        }
        .onAppear {
            // Show saved toast briefly
            if !companyName.isEmpty {
                showSavedToast = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { showSavedToast = false }
                }
            }
        }
    }

    private func fieldRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.inkMuted)
            content()
        }
    }

    private func exportCSV() {
        do {
            let exportDir = try BackupService.exportCSVBundle(modelContext: modelContext)
            let panel = NSSavePanel()
            panel.title = "Save CSV Export"
            panel.nameFieldStringValue = exportDir.lastPathComponent
            panel.canCreateDirectories = true
            guard panel.runModal() == .OK, let dest = panel.url else { return }
            try FileManager.default.copyItem(at: exportDir, to: dest)
            backupIsError = false
            backupMessage = "CSV exported to \(dest.lastPathComponent)"
        } catch {
            backupIsError = true
            backupMessage = ErrorMapper.userMessage(from: error)
        }
    }

    private func exportDatabase() {
        do {
            let exportDir = try BackupService.exportDatabaseCopy(modelContext: modelContext)
            let panel = NSSavePanel()
            panel.title = "Save Database Backup"
            panel.nameFieldStringValue = exportDir.lastPathComponent
            panel.canCreateDirectories = true
            guard panel.runModal() == .OK, let dest = panel.url else { return }
            try FileManager.default.copyItem(at: exportDir, to: dest)
            backupIsError = false
            backupMessage = "Database exported to \(dest.lastPathComponent)"
        } catch {
            backupIsError = true
            backupMessage = ErrorMapper.userMessage(from: error)
        }
    }

    private func agingRow(label: String, value: Binding<Int>) -> some View {
        HStack {
            Text(label)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.inkMuted)
            Spacer()
            TextField("", value: value, format: .number)
                .frame(width: 60)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.center)
        }
    }

    private func pickBackupToRestore() {
        let panel = NSOpenPanel()
        panel.title = "Select Database Backup Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select a QDI_Backup folder previously exported from this app."

        guard panel.runModal() == .OK, let url = panel.url else { return }
        pendingRestoreURL = url
        showRestoreConfirm = true
    }

    private func performRestore() {
        guard let backupURL = pendingRestoreURL else { return }
        pendingRestoreURL = nil
        do {
            try BackupService.restoreDatabase(from: backupURL, modelContext: modelContext)
            backupIsError = false
            backupMessage = "Restore successful. Quitting app — please relaunch."
            // Quit after a short delay so the user can read the message
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                NSApplication.shared.terminate(nil)
            }
        } catch {
            backupIsError = true
            backupMessage = "Restore failed: \(ErrorMapper.userMessage(from: error))"
        }
    }

    private func pickBackupDirectory() {
        let panel = NSOpenPanel()
        panel.title = "Choose Automatic Backup Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        backupScheduler.backupDirectory = url
    }

    private func pickLogo() {
        let panel = NSOpenPanel()
        panel.title = "Choose Company Logo"
        panel.allowedContentTypes = [.png, .jpeg, .heic]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            logoData = data
            PDFService.saveCompanyLogo(data)
        } catch {
            AppLogger.ui.error("Failed to load logo image: \(error.localizedDescription)")
        }
    }
}
