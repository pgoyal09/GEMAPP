import SwiftUI
import SwiftData
import AppKit

// MARK: - Dashboard View (QuickBooks-inspired 2-column layout)

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) var openWindow
    @EnvironmentObject var rfidManager: RFIDManager
    @Binding var selectedNavigationItem: NavigationItem
    @State var viewModel = DashboardViewModel()
    @State private var showAddStoneSheet = false
    @State var selectedMemoID: PersistentIdentifier?
    @State private var selectedPanelItem: DashboardPanelItem = .none
    @State var showResetConfirm = false
    @State private var resetSuccessMessage: String?
    @State var isResetting = false

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ScrollView {
                leftColumnContent
            }
            .frame(maxWidth: .infinity)

            infoPanel
        }
        .sheet(isPresented: $showAddStoneSheet) {
            NavigationStack { AddGemstoneView() }
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
            Button("Reset", role: .destructive) {
                performReset()
            }
        } message: {
            Text("This will delete and recreate all demo data.")
        }
        .overlay {
            if let msg = resetSuccessMessage {
                VStack {
                    Spacer()
                    Text(msg)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, AppSpacing.l)
                        .padding(.vertical, AppSpacing.m)
                        .background(AppColors.success)
                        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.m, style: .continuous))
                        .padding(.bottom, AppSpacing.xl)
                }
                .transition(.move(edge: .bottom))
                .animation(.easeInOut(duration: 0.3), value: resetSuccessMessage)
            }
        }
    }

    private func performReset() {
        guard !isResetting else { return }
        isResetting = true
        resetSuccessMessage = nil
        Task {
            do {
                try await DemoDataManager.resetAllData(modelContext: modelContext)
                await MainActor.run {
                    viewModel.load(modelContext: modelContext)
                    resetSuccessMessage = "Demo data reset successfully."
                    isResetting = false
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(2.5))
                        withAnimation { resetSuccessMessage = nil }
                    }
                }
            } catch {
                await MainActor.run {
                    resetSuccessMessage = "Error: \(error.localizedDescription)"
                    isResetting = false
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(3))
                        withAnimation { resetSuccessMessage = nil }
                    }
                }
            }
        }
    }

    private var leftColumnContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            summaryWidgetsRow
            functionCardGrid
            recentActivitySection
            resetDataSection
            Spacer(minLength: AppSpacing.xl)
        }
        .padding(24)
    }

    private var functionCardGrid: some View {
        GlassCard(padding: 20) {
            VStack(alignment: .leading, spacing: 16) {
                Text("QUICK ACTIONS")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.50))
                    .tracking(1.5)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                    DashboardActionCard(title: "Add Stone", icon: "diamond.fill", gradient: "cyan-blue") {
                        selectedPanelItem = .addStone
                        showAddStoneSheet = true
                    }
                    DashboardActionCard(title: "Quick Intake", icon: "plus.circle.fill", gradient: "emerald-teal") {
                        selectedNavigationItem = .quickIntake
                    }
                    DashboardActionCard(title: "Review Queue", icon: "list.bullet.clipboard", gradient: "violet-purple") {
                        selectedNavigationItem = .reviewQueue
                    }
                    DashboardActionCard(title: "New Memo", icon: "doc.text.fill", gradient: "amber-orange") {
                        selectedPanelItem = .newMemo
                        let memo = TransactionViewModel.createNewMemo(modelContext: modelContext)
                        openWindow(id: "memo", value: memo.id)
                    }
                    DashboardActionCard(title: "New Invoice", icon: "doc.richtext.fill", gradient: "rose-pink") {
                        selectedPanelItem = .newInvoice
                        let invoice = TransactionViewModel.createNewInvoice(modelContext: modelContext)
                        openWindow(id: "invoice", value: invoice.id)
                    }
                    DashboardActionCard(title: "Inventory", icon: "square.grid.2x2.fill", gradient: "teal-cyan") {
                        selectedNavigationItem = .inventory
                    }
                    DashboardActionCard(title: "Customers", icon: "person.2.fill", gradient: "blue-indigo") {
                        selectedNavigationItem = .customers
                    }
                    DashboardActionCard(title: "Scanner", icon: "antenna.radiowaves.left.and.right", gradient: "gray-slate") {
                        selectedNavigationItem = .scanner
                    }
                }
            }
        }
    }

    private var summaryWidgetsRow: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 4), spacing: 16) {
            DashboardWidgetCard(title: "Total Carats", value: String(format: "%.2f", viewModel.totalCaratsInStock), unit: "ct", icon: "diamond")
            DashboardWidgetCard(title: "Value on Memo", value: viewModel.totalValueOnMemo.asCurrency, icon: "doc.text")
            DashboardWidgetCard(title: "Items on Memo", value: "\(viewModel.inventorySnapshot.onMemoCount)", icon: "tray.full")
            DashboardWidgetCard(title: "Available", value: "\(viewModel.inventorySnapshot.availableCount)", icon: "checkmark.circle")
        }
    }

    // MARK: - Info Panel (Right Column)

    private var infoPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                rfidStatusPill
                oldestOpenMemosSection
                inventorySnapshotSection
                if let memoID = selectedMemoID, let item = viewModel.oldestOpenMemos.first(where: { $0.id == memoID }) {
                    memoDetailSummary(item: item)
                }
            }
            .padding(20)
        }
        .frame(width: 296)
        .background(Color.white.opacity(0.02))
        .overlay(alignment: .leading) {
            Divider().background(Color.white.opacity(0.06))
        }
    }
}
