import SwiftUI
import SwiftData
import AppKit

struct DashboardView: View {
    @Binding var navigateTo: NavigationItem
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State var viewModel = DashboardViewModel()
    @State private var showAddStoneSheet = false
    @State private var showResetConfirm = false
    @State private var isResetting = false
    @State private var toastMessage: String?
    @State private var refreshTask: Task<Void, Never>?
    @State private var checklistRefreshTrigger: Int = 0
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.hero) {
                    if !hasSeenWelcome {
                        welcomeBanner
                    }
                    GettingStartedChecklist(refreshTrigger: checklistRefreshTrigger) { item in
                        handleChecklistNavigation(item)
                    }
                    KPICardRow(viewModel: viewModel)
                    QuickActionsGrid(navigateTo: $navigateTo, onAddStone: { showAddStoneSheet = true })
                    RecentActivityList(items: viewModel.recentActivity)
                    #if DEBUG
                    resetDataButton
                    #endif
                    Spacer(minLength: AppSpacing.hero)
                }
                .padding(AppSpacing.hero)
            }
            .frame(maxWidth: .infinity)

            DashboardInfoPanel(viewModel: viewModel)
        }
        .accessibilityIdentifier("DashboardView")
        .sheet(isPresented: $showAddStoneSheet) {
            NavigationStack { StoneFormView(mode: .intake) }
                .presentationDetents([.medium, .large])
        }
        .onAppear { debouncedRefresh() }
        .onChange(of: showAddStoneSheet) { _, _ in debouncedRefresh() }
        .onReceive(NotificationCenter.default.publisher(for: .dataStoreDidChange)) { _ in
            debouncedRefresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            debouncedRefresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: .memoOrInvoiceDidSave)) { _ in
            debouncedRefresh()
        }
        .alert("Reset Demo Data", isPresented: $showResetConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) { performReset() }
        } message: {
            Text("This will delete and recreate all demo data.")
        }
        .overlay {
            if let msg = toastMessage {
                ToastOverlay(message: msg)
                    .animation(reduceMotion ? nil : AppAnimation.standard, value: toastMessage)
            }
        }
    }

    private var welcomeBanner: some View {
        VStack(alignment: .leading, spacing: AppSpacing.standard) {
            HStack {
                Image(systemName: "sparkles")
                    .font(AppTypography.heading)
                    .foregroundStyle(AppColors.primary)
                Text("Welcome to QDI Gemstone ERP")
                    .font(AppTypography.heading)
                    .foregroundStyle(AppColors.ink)
                Spacer()
                Button {
                    withAnimation { hasSeenWelcome = true }
                } label: {
                    Image(systemName: "xmark")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.inkSubtle)
                }
                .buttonStyle(.plain)
            }
            Text("Get started: add your first gemstone via Quick Intake (⌘9), or import inventory from a CSV file in the Inventory section.")
                .font(AppTypography.body)
                .foregroundStyle(AppColors.inkSubtle)
        }
        .padding(AppSpacing.section)
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                .fill(AppColors.primary.opacity(AppOpacity.subtle))
                .overlay(
                    RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                        .strokeBorder(AppColors.primary.opacity(AppOpacity.muted), lineWidth: 1)
                )
        )
    }

    private var resetDataButton: some View {
        Button { showResetConfirm = true } label: {
            HStack(spacing: AppSpacing.standard) {
                Image(systemName: "arrow.clockwise.circle").font(AppTypography.caption)
                Text("Generate New Mock Data").font(AppTypography.body)
            }
            .foregroundStyle(AppColors.inkSubtle)
            .padding(.horizontal, AppSpacing.section)
            .padding(.vertical, AppSpacing.standard)
            .background(
                RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                    .fill(AppColors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                            .strokeBorder(AppColors.cardStroke, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Generate New Mock Data")
        .disabled(isResetting)
    }

    // MARK: - Getting Started Navigation

    private func handleChecklistNavigation(_ item: GettingStartedItem) {
        switch item {
        case .addFirstStone:
            showAddStoneSheet = true
        case .createMemo:
            navigateTo = .memos
        case .createInvoice:
            navigateTo = .invoices
        case .setupBackup:
            navigateTo = .settings
        case .explorePrinter:
            navigateTo = .settings
        }
    }

    /// Debounced refresh — coalesces rapid notification bursts into a single reload
    private func debouncedRefresh() {
        refreshTask?.cancel()
        refreshTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            GettingStartedService.autoDetectProgress(modelContext: modelContext)
            checklistRefreshTrigger += 1
            viewModel.load(modelContext: modelContext)
        }
    }

    private func performReset() {
        guard !isResetting else { return }
        isResetting = true
        Task {
            do {
                try DemoDataService.resetAllData(modelContext: modelContext)
                viewModel.load(modelContext: modelContext)
                toastMessage = "Demo data reset successfully."
            } catch {
                toastMessage = "Error: \(ErrorMapper.userMessage(from: error))"
            }
            isResetting = false
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation(reduceMotion ? nil : .default) { toastMessage = nil }
        }
    }
}
