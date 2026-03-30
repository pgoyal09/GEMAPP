import SwiftUI
import SwiftData
import AppKit

struct DashboardView: View {
    @Binding var navigateTo: NavigationItem
    @Environment(\.modelContext) private var modelContext
    @State var viewModel = DashboardViewModel()
    @State private var showAddStoneSheet = false
    @State private var showResetConfirm = false
    @State private var isResetting = false
    @State private var toastMessage: String?

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.section) {
                    KPICardRow(viewModel: viewModel)
                    QuickActionsGrid(navigateTo: $navigateTo, onAddStone: { showAddStoneSheet = true })
                    RecentActivityList(items: viewModel.recentActivity)
                    #if DEBUG
                    resetDataButton
                    #endif
                    Spacer(minLength: AppSpacing.xl)
                }
                .padding(AppSpacing.section)
            }
            .frame(maxWidth: .infinity)

            DashboardInfoPanel(viewModel: viewModel)
        }
        .accessibilityIdentifier("DashboardView")
        .sheet(isPresented: $showAddStoneSheet) {
            NavigationStack { StoneFormView(mode: .intake) }
                .presentationDetents([.medium, .large])
        }
        .onAppear { viewModel.load(modelContext: modelContext) }
        .onChange(of: showAddStoneSheet) { _, _ in viewModel.load(modelContext: modelContext) }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            viewModel.load(modelContext: modelContext)
        }
        .onReceive(NotificationCenter.default.publisher(for: .memoOrInvoiceDidSave)) { _ in
            viewModel.load(modelContext: modelContext)
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
                    .animation(AppAnimation.standard, value: toastMessage)
            }
        }
    }

    private var resetDataButton: some View {
        Button { showResetConfirm = true } label: {
            HStack(spacing: AppSpacing.compact) {
                Image(systemName: "arrow.clockwise.circle").font(.system(size: 13))
                Text("Generate New Mock Data").font(AppTypography.body)
            }
            .foregroundStyle(AppColors.inkSubtle)
            .padding(.horizontal, AppSpacing.standard)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: AppCornerRadius.m, style: .continuous)
                    .fill(Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppCornerRadius.m, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Generate New Mock Data")
        .disabled(isResetting)
    }

    private func performReset() {
        guard !isResetting else { return }
        isResetting = true
        Task {
            do {
                try await DemoDataService.resetAllData(modelContext: modelContext)
                viewModel.load(modelContext: modelContext)
                toastMessage = "Demo data reset successfully."
            } catch {
                toastMessage = "Error: \(ErrorMapper.userMessage(from: error))"
            }
            isResetting = false
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation { toastMessage = nil }
        }
    }
}
