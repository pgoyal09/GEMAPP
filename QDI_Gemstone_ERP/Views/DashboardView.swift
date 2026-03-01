import SwiftUI
import SwiftData
import AppKit

// MARK: - Dashboard View (QuickBooks-inspired 2-column layout)

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var rfidManager: RFIDManager
    @Binding var selectedNavigationItem: NavigationItem
    @State private var viewModel = DashboardViewModel()
    @State private var showAddStoneSheet = false
    @State private var selectedMemoID: PersistentIdentifier?
    @State private var selectedPanelItem: DashboardPanelItem = .none
    @State private var showResetConfirm = false
    @State private var resetSuccessMessage: String?
    @State private var isResetting = false

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ScrollView {
                leftColumnContent
            }
            .frame(maxWidth: .infinity)

            infoPanel
        }
        .background(AppColors.shellGradient)
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
        VStack(alignment: .leading, spacing: AppSpacing.xl) {
            headerRow
            functionCardGrid
            summaryWidgetsRow
            recentActivitySection
            Spacer(minLength: AppSpacing.xl)
        }
        .padding(AppSpacing.xl)
    }

    private var headerRow: some View {
        HStack {
            Text("Dashboard")
                .font(AppTypography.title)
                .foregroundStyle(AppColors.ink)
            Spacer()
            TextField("Search…", text: .constant(""))
                .appSearchField()
                .frame(maxWidth: 200)
        }
    }

    private var functionCardGrid: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            SectionHeader(title: "Quick Actions")
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: AppSpacing.m),
                GridItem(.flexible(), spacing: AppSpacing.m),
                GridItem(.flexible(), spacing: AppSpacing.m),
                GridItem(.flexible(), spacing: AppSpacing.m),
            ], spacing: AppSpacing.m) {
                DashboardActionCard(title: "Add Stone", subtitle: "Add new gemstone", icon: "diamond.fill") {
                    selectedPanelItem = .addStone
                    showAddStoneSheet = true
                }
                DashboardActionCard(title: "Quick Intake", subtitle: "Fast keyboard entry", icon: "plus.circle.fill") {
                    selectedNavigationItem = .quickIntake
                }
                DashboardActionCard(title: "Review Queue", subtitle: "Complete missing fields", icon: "list.bullet.clipboard") {
                    selectedNavigationItem = .reviewQueue
                }
                DashboardActionCard(title: "New Memo", subtitle: "Create consignment memo", icon: "doc.text.fill") {
                    selectedPanelItem = .newMemo
                    let memo = TransactionViewModel.createNewMemo(modelContext: modelContext)
                    openWindow(id: "memo", value: memo.id)
                }
                DashboardActionCard(title: "New Invoice", subtitle: "Create sales invoice", icon: "doc.richtext.fill") {
                    selectedPanelItem = .newInvoice
                    let invoice = TransactionViewModel.createNewInvoice(modelContext: modelContext)
                    openWindow(id: "invoice", value: invoice.id)
                }
                DashboardActionCard(title: "Inventory", subtitle: "View all stones", icon: "square.grid.2x2.fill") {
                    selectedNavigationItem = .inventory
                }
                DashboardActionCard(title: "Memos", subtitle: "Open memos", icon: "doc.text.fill") {
                    selectedNavigationItem = .memos
                }
                DashboardActionCard(title: "Invoices", subtitle: "Sales invoices", icon: "dollarsign.circle.fill") {
                    selectedNavigationItem = .invoices
                }
                DashboardActionCard(title: "Customers", subtitle: "Customer list", icon: "person.2.fill") {
                    selectedNavigationItem = .customers
                }
                DashboardActionCard(title: "Scanner", subtitle: "RFID & reconcile", icon: "antenna.radiowaves.left.and.right") {
                    selectedNavigationItem = .scanner
                }
            }
        }
    }

    private var summaryWidgetsRow: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            SectionHeader(title: "Summary")
            HStack(spacing: AppSpacing.m) {
                DashboardWidgetCard(title: "Total Carats in Stock", value: String(format: "%.2f ct", viewModel.totalCaratsInStock))
                DashboardWidgetCard(title: "Total Value on Memo", value: formatCurrency(viewModel.totalValueOnMemo))
                if viewModel.inventorySnapshot.onMemoCount > 0 || viewModel.inventorySnapshot.availableCount > 0 {
                    DashboardWidgetCard(title: "Items on Memo", value: "\(viewModel.inventorySnapshot.onMemoCount)")
                    DashboardWidgetCard(title: "Available", value: "\(viewModel.inventorySnapshot.availableCount)")
                }
            }
        }
    }

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            SectionHeader(title: "Recent Activity")
            AppCard {
                if viewModel.recentActivity.isEmpty {
                    Text("No recent activity")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(AppSpacing.m)
                } else {
                    VStack(alignment: .leading, spacing: AppSpacing.s) {
                        ForEach(viewModel.recentActivity) { activity in
                            Button {
                                openWindow(id: "memo", value: activity.id)
                            } label: {
                                Text(activity.title)
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(AppSpacing.m)
                    }
                }
            }
        }
    }

    // MARK: - Info Panel (Right Column)

    private var infoPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.l) {
                SectionHeader(title: "Info")
                rfidStatusPill
                oldestOpenMemosSection
                inventorySnapshotSection
                if let memoID = selectedMemoID, let item = viewModel.oldestOpenMemos.first(where: { $0.id == memoID }) {
                    memoDetailSummary(item: item)
                }
                Spacer(minLength: AppSpacing.xl)
                Button {
                    showResetConfirm = true
                } label: {
                    Label("Generate New Mock Data", systemImage: "arrow.clockwise.circle")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isResetting)
            }
            .padding(AppSpacing.l)
        }
        .frame(width: 296)
        .background(AppColors.panelBackground)
    }

    private var rfidStatusPill: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            StatusPill(
                label: rfidManager.connectionStatus.rawValue,
                color: statusColor
            ) {
                rfidManager.reconnect()
            }
            if let err = rfidManager.lastErrorMessage {
                Text(err)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
            if rfidManager.connectionStatus == .scanning {
                HStack(spacing: 8) {
                    Text("Unique: \(rfidManager.uniqueTagsThisSession)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let tag = rfidManager.lastScannedTag {
                        Text(truncatedHex(tag))
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                HStack(spacing: 8) {
                    Button(rfidManager.isScanningPaused ? "Resume" : "Pause") {
                        if rfidManager.isScanningPaused {
                            rfidManager.resumeScanning()
                        } else {
                            rfidManager.pauseScanning()
                        }
                    }
                    .buttonStyle(.borderless)
                    .font(.caption2)
                    Button("Reset Session") {
                        rfidManager.resetScanSession()
                    }
                    .buttonStyle(.borderless)
                    .font(.caption2)
                }
            }
        }
    }

    private func truncatedHex(_ s: String) -> String {
        guard s.count > 24 else { return s }
        return String(s.prefix(12)) + "…" + String(s.suffix(8))
    }

    private var statusColor: Color {
        switch rfidManager.connectionStatus {
        case .disconnected: return AppColors.inkSubtle
        case .connecting, .initializing: return AppColors.warning
        case .connected, .scanning: return AppColors.success
        case .error: return AppColors.danger
        }
    }

    private var oldestOpenMemosSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Text("Oldest Open Memos")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            if viewModel.oldestOpenMemos.isEmpty {
                Text("No open memos")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(AppSpacing.s)
            } else {
                VStack(spacing: 0) {
                    ForEach(viewModel.oldestOpenMemos) { item in
                        memoRowButton(item: item)
                    }
                }
            }
        }
    }

    private func memoRowButton(item: OldestMemoItem) -> some View {
        Button {
            openWindow(id: "memo", value: item.id)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("#\(item.referenceNumber ?? "—")")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(item.customerName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(item.ageDays)d")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formatCurrency(item.totalAmount))
                        .font(.caption)
                }
            }
            .padding(AppSpacing.s)
            .contentShape(Rectangle())
            .background(selectedMemoID == item.id ? AppColors.primary.opacity(0.2) : Color.clear)
        }
        .buttonStyle(.plain)
    }

    private func memoDetailSummary(item: OldestMemoItem) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                Text("Memo #\(item.referenceNumber ?? "—")")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("Customer: \(item.customerName)")
                    .font(.caption)
                Text("Total: \(formatCurrency(item.totalAmount))")
                    .font(.caption)
                Text("Status: \(item.status.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.m)
        }
    }

    private var inventorySnapshotSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Text("Inventory Snapshot")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            HStack(spacing: AppSpacing.m) {
                snapshotChip("Available", viewModel.inventorySnapshot.availableCount)
                snapshotChip("On Memo", viewModel.inventorySnapshot.onMemoCount)
                snapshotChip("Sold", viewModel.inventorySnapshot.soldCount)
            }
        }
    }

    private func snapshotChip(_ label: String, _ count: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.headline)
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.s)
        .background(AppColors.primary.opacity(0.1))
        .cornerRadius(AppCornerRadius.s)
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        return f.string(from: value as NSDecimalNumber) ?? "$0"
    }
}

// MARK: - Panel Selection (for future preview/summary)

enum DashboardPanelItem {
    case none, addStone, newMemo, newInvoice
}

// MARK: - Reusable Components

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(AppTypography.heading)
            .foregroundStyle(AppColors.ink)
    }
}

struct StatusPill: View {
    let label: String
    let color: Color
    var onReconnect: () -> Void

    var body: some View {
        AppSurfaceCard(padding: AppSpacing.m, accent: color) {
            HStack {
                AppStatusBadge(title: label, tone: tone(for: label))
                Spacer()
                Button("Reconnect", action: onReconnect)
                    .buttonStyle(.bordered)
                    .tint(AppColors.primary)
            }
        }
    }

    private func tone(for label: String) -> AppStatusBadge.Tone {
        let v = label.lowercased()
        if v.contains("scan") || v.contains("connect") { return .success }
        if v.contains("initial") || v.contains("connect") { return .warning }
        if v.contains("error") || v.contains("disconnect") { return .danger }
        return .neutral
    }
}

struct AppCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        AppSurfaceCard(padding: AppSpacing.m) {
            content()
        }
    }
}

struct DashboardActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let action: () -> Void

    private static let cardHeight: CGFloat = 110
    private static let internalSpacing: CGFloat = AppSpacing.s

    var body: some View {
        Button(action: action) {
            AppSurfaceCard(padding: AppSpacing.m, accent: AppColors.accent) {
                VStack(alignment: .leading, spacing: Self.internalSpacing) {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(AppColors.primary)
                    Text(title)
                        .font(AppTypography.body.weight(.semibold))
                        .foregroundStyle(AppColors.ink)
                    Text(subtitle)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.inkSubtle)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: Self.cardHeight)
        }
        .buttonStyle(.plain)
    }
}

struct DashboardWidgetCard: View {
    let title: String
    let value: String

    var body: some View {
        AppSurfaceCard(padding: AppSpacing.m, accent: AppColors.primary) {
            Text(title)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.inkSubtle)
            Text(value)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.ink)
        }
    }
}
