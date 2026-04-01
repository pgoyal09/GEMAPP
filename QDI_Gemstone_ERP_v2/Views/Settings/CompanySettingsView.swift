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
    @AppStorage("requireSalespersonOnMemos") private var requireSalesperson: Bool = true
    @AppStorage("displayFontSize") private var displayFontSize: String = "Small"
    @AppStorage("memoAgingGreen") private var memoAgingGreen: Int = 7
    @AppStorage("memoAgingYellow") private var memoAgingYellow: Int = 14
    @AppStorage("memoAgingOrange") private var memoAgingOrange: Int = 30
    @State private var backupMessage: String?
    @State private var backupIsError = false
    @State private var showRestoreConfirm = false
    @State private var pendingRestoreURL: URL?
    @State private var backupScheduler = BackupScheduler()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.hero) {

                // MARK: - Company Info

                settingsSection(title: "Company Branding") {
                    FormField(label: "Company Name", text: $companyName)

                    fieldRow(label: "Address") {
                        TextEditor(text: $companyAddress)
                            .font(.body)
                            .frame(height: 60)
                            .padding(AppSpacing.compact)
                            .background(
                                RoundedRectangle(cornerRadius: AppCornerRadius.field, style: .continuous)
                                    .fill(AppColors.cardBackground)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppCornerRadius.field, style: .continuous)
                                            .strokeBorder(AppColors.cardStroke, lineWidth: 1)
                                    )
                            )
                            .scrollContentBackground(.hidden)
                    }

                    FormField(label: "Phone", text: $companyPhone)
                    FormField(label: "Email", text: $companyEmail)

                    fieldRow(label: "Logo") {
                        HStack(spacing: AppSpacing.comfortable) {
                            if let data = logoData, let nsImage = NSImage(data: data) {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 56)
                                    .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.field))

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

                if showSavedToast {
                    HStack(spacing: AppSpacing.compact) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppColors.success)
                        Text("Settings saved automatically")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.inkMuted)
                    }
                    .transition(.opacity)
                }

                // MARK: - Salesperson Toggle

                settingsSection(title: "Memo Settings") {
                    Toggle("Require Salesperson on Memos", isOn: $requireSalesperson)
                        .toggleStyle(.checkbox)
                    Text("When disabled, the salesperson field is hidden on memo forms.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.inkSubtle)
                }

                // MARK: - Font Size Picker

                settingsSection(title: "Display Font Size") {
                    Picker("Font Size", selection: $displayFontSize) {
                        Text("Small").tag("Small")
                        Text("Medium").tag("Medium")
                        Text("Large").tag("Large")
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 300)
                    Text("Small = default sizes. Medium = +2pt. Large = +4pt.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.inkSubtle)
                }

                // MARK: - Memo Aging Thresholds

                settingsSection(title: "Memo Aging Alerts") {
                    agingRow(label: "Green → Yellow (days)", value: $memoAgingGreen)
                    agingRow(label: "Yellow → Orange (days)", value: $memoAgingYellow)
                    agingRow(label: "Orange → Red (days)", value: $memoAgingOrange)
                    Text("Memos are color-coded by age on the dashboard.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.inkSubtle)
                }

                // MARK: - RFID / Label Settings

                SectionHeader(title: "Label Printing")

                LabelSettingsView()
                    .frame(maxWidth: .infinity)

                // MARK: - RapNet Integration

                SectionHeader(title: "RapNet Integration")

                RapNetSettingsView()
                    .frame(maxWidth: .infinity)

                // MARK: - Automatic Backup

                settingsSection(title: "Automatic Backup") {
                    Toggle("Enable scheduled backups", isOn: $backupScheduler.isEnabled)
                        .toggleStyle(.checkbox)

                    if backupScheduler.isEnabled {
                        HStack(spacing: AppSpacing.comfortable) {
                            Text("Interval (hours)")
                                .font(AppTypography.body)
                                .foregroundStyle(AppColors.inkMuted)
                            TextField("", value: $backupScheduler.intervalHours, format: .number)
                                .frame(width: 60)
                                .textFieldStyle(.roundedBorder)
                                .multilineTextAlignment(.center)
                        }

                        HStack(spacing: AppSpacing.comfortable) {
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

                        HStack(spacing: AppSpacing.compact) {
                            Image(systemName: "clock")
                                .font(AppTypography.caption)
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

                // MARK: - Backup & Export

                settingsSection(title: "Backup & Export") {
                    HStack(spacing: AppSpacing.comfortable) {
                        Button("Export CSV Bundle…") { exportCSV() }
                            .buttonStyle(.outline)
                        Button("Export Database Copy…") { exportDatabase() }
                            .buttonStyle(.outline)
                        Button("Restore from Backup…") { pickBackupToRestore() }
                            .buttonStyle(.outline(AppColors.warning))
                    }

                    if let msg = backupMessage {
                        HStack(spacing: AppSpacing.compact) {
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

                // MARK: - Cloud Backup

                SectionHeader(title: "Cloud Backup")

                CloudBackupSettingsView()
                    .frame(maxWidth: .infinity)

                // MARK: - Help Center

                settingsSection(title: "Help Center") {
                    HStack(spacing: AppSpacing.standard) {
                        Image(systemName: "questionmark.circle")
                            .font(AppTypography.heading)
                            .foregroundStyle(AppColors.primary)
                        VStack(alignment: .leading, spacing: AppSpacing.compact) {
                            Text("Open Help Center")
                                .font(AppTypography.body)
                                .foregroundStyle(AppColors.ink)
                            Text("Glossary, keyboard shortcuts, and guides")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.inkSubtle)
                        }
                        Spacer()
                        Text("⌘?")
                            .font(AppTypography.mono)
                            .foregroundStyle(AppColors.inkSubtle)
                            .padding(.horizontal, AppSpacing.standard)
                            .padding(.vertical, AppSpacing.compact)
                            .background(
                                RoundedRectangle(cornerRadius: AppCornerRadius.field, style: .continuous)
                                    .fill(AppColors.softHighlight)
                            )
                    }
                }

                Text("These details appear on generated PDF invoices and memos.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.inkSubtle)

                Spacer()
            }
            .padding(AppSpacing.hero)
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
            if !companyName.isEmpty {
                showSavedToast = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation(reduceMotion ? nil : .default) { showSavedToast = false }
                }
            }
        }
    }

    // MARK: - Reusable Section Card

    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.section) {
            SectionHeader(title: title)
            VStack(alignment: .leading, spacing: AppSpacing.comfortable) {
                content()
            }
            .padding(AppSpacing.hero)
            .background(
                RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                    .fill(AppColors.panelBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                            .strokeBorder(AppColors.cardStroke, lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - Helpers

    private func fieldRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.compact) {
            Text(label)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.inkMuted)
            content()
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

    // MARK: - Actions

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
