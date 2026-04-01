import SwiftUI
import SwiftData

struct RapNetSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var syncService = RapNetSyncService()
    @State private var connectionStatus: ConnectionState = .idle
    @State private var toastMessage: String?
    @State private var toastIsError = false

    enum ConnectionState {
        case idle, testing, success, failed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.hero) {
            credentialsSection
            syncControlsSection
            syncLogSection

            NavigationLink(destination: RapNetFieldsView()) {
                HStack(spacing: AppSpacing.standard) {
                    Image(systemName: "list.bullet.rectangle.portrait")
                    Text("RapNet Upload Fields Reference")
                }
                .font(AppTypography.body)
                .foregroundStyle(AppColors.primary)
            }
            .buttonStyle(.plain)
        }
        .onAppear { syncService.cachedContext = modelContext }
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
        .accessibilityIdentifier("RapNetSettingsView")
    }

    // MARK: - Credentials

    private var credentialsSection: some View {
        GlassCard(padding: AppSpacing.hero) {
            VStack(alignment: .leading, spacing: AppSpacing.section) {
                SectionHeader(title: "RapNet Credentials")

                HStack(spacing: AppSpacing.section) {
                    VStack(alignment: .leading, spacing: AppSpacing.compact) {
                        Text("Username")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.inkSubtle)
                        TextField("RapNet username", text: Binding(
                            get: { syncService.username },
                            set: { syncService.username = $0 }
                        ))
                        .glassField()
                        .accessibilityLabel("RapNet username")
                    }

                    VStack(alignment: .leading, spacing: AppSpacing.compact) {
                        Text("Password")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.inkSubtle)
                        SecureField("RapNet password", text: Binding(
                            get: { syncService.password },
                            set: { syncService.password = $0 }
                        ))
                        .glassField()
                        .accessibilityLabel("RapNet password")
                    }
                }

                HStack(spacing: AppSpacing.section) {
                    Button {
                        Task { await testConnection() }
                    } label: {
                        HStack(spacing: AppSpacing.standard) {
                            if connectionStatus == .testing {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text("Test Connection")
                        }
                    }
                    .buttonStyle(.outline)
                    .disabled(connectionStatus == .testing || syncService.username.isEmpty || syncService.password.isEmpty)
                    .accessibilityLabel("Test RapNet connection")

                    if connectionStatus == .success {
                        Label("Connected", systemImage: "checkmark.circle.fill")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.success)
                    } else if connectionStatus == .failed {
                        Label(syncService.lastError ?? "Failed", systemImage: "xmark.circle.fill")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.danger)
                    }
                }
            }
        }
    }

    // MARK: - Sync Controls

    private var syncControlsSection: some View {
        GlassCard(padding: AppSpacing.hero) {
            VStack(alignment: .leading, spacing: AppSpacing.section) {
                SectionHeader(title: "Sync Controls")

                HStack(spacing: AppSpacing.section) {
                    Button {
                        Task { await syncNow() }
                    } label: {
                        HStack(spacing: AppSpacing.standard) {
                            if syncService.isSyncing {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text("Sync Now")
                        }
                    }
                    .buttonStyle(.gradient)
                    .disabled(syncService.isSyncing || syncService.username.isEmpty)
                    .accessibilityLabel("Sync inventory to RapNet now")

                    Button("Pull Prices") {
                        Task { await pullPrices() }
                    }
                    .buttonStyle(.outline)
                    .disabled(syncService.isSyncing || syncService.username.isEmpty)
                    .accessibilityLabel("Pull Rapaport prices")
                }

                HStack(spacing: AppSpacing.section) {
                    Toggle("Auto-sync every 4 hours", isOn: Binding(
                        get: { syncService.autoSyncEnabled },
                        set: { syncService.autoSyncEnabled = $0 }
                    ))
                    .toggleStyle(.switch)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.ink)
                    .accessibilityLabel("Enable automatic RapNet sync every 4 hours")

                    Spacer()
                }

                if let lastSync = syncService.lastSyncDate {
                    DetailRow(label: "Last Sync", value: lastSync.formatted(date: .abbreviated, time: .shortened))
                }
            }
        }
    }

    // MARK: - Sync Log

    private var syncLogSection: some View {
        GlassCard(padding: AppSpacing.hero) {
            VStack(alignment: .leading, spacing: AppSpacing.section) {
                SectionHeader(title: "Sync Log")

                if syncService.syncLog.isEmpty {
                    Text("No sync events yet")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.inkSubtle)
                } else {
                    ForEach(Array(syncService.syncLog.enumerated()), id: \.element.id) { index, entry in
                        HStack(spacing: AppSpacing.comfortable) {
                            Image(systemName: entry.status == "Success" ? "checkmark.circle.fill" : entry.status == "Skipped" ? "minus.circle" : "xmark.circle.fill")
                                .foregroundStyle(entry.status == "Success" ? AppColors.success : entry.status == "Skipped" ? AppColors.inkSubtle : AppColors.danger)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.action)
                                    .font(AppTypography.body)
                                    .foregroundStyle(AppColors.ink)
                                Text(entry.detail)
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.inkSubtle)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Text(entry.date.formatted(date: .omitted, time: .shortened))
                                .font(AppTypography.mono)
                                .foregroundStyle(AppColors.inkSubtle)
                        }
                        .padding(.vertical, AppSpacing.compact)
                        .staggeredRow(index: index, reduceMotion: reduceMotion)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(entry.action): \(entry.status), \(entry.detail)")
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func testConnection() async {
        connectionStatus = .testing
        let success = await syncService.testConnection()
        connectionStatus = success ? .success : .failed
        toastMessage = success ? "Connected to RapNet" : "Connection failed"
        toastIsError = !success
    }

    private func syncNow() async {
        await syncService.uploadInventory(modelContext: modelContext)
        toastMessage = syncService.lastError == nil ? "Inventory uploaded to RapNet" : syncService.lastError
        toastIsError = syncService.lastError != nil
    }

    private func pullPrices() async {
        await syncService.pullPriceSheet(modelContext: modelContext)
        toastMessage = syncService.lastError == nil ? "Prices updated" : syncService.lastError
        toastIsError = syncService.lastError != nil
    }
}
