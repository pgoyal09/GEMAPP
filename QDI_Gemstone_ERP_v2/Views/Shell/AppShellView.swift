import SwiftUI
import SwiftData

struct AppShellView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @Environment(\.rfidCoordinator) private var rfidCoordinator

    @State private var route: NavigationItem = .dashboard
    @State private var pendingRoute: NavigationItem?
    @State private var showLeaveAlert = false
    @State private var navigationGuard = NavigationGuard()
    @State private var showSidebar: Bool = true
    @State private var showAddStoneFromMenu = false
    @AppStorage("appAppearance") private var appAppearance: String = "dark"

    private var resolvedColorScheme: ColorScheme? {
        switch appAppearance {
        case "light": return .light
        case "dark": return .dark
        default: return nil // system
        }
    }

    // Persistent scanner/reconcile VMs so session state survives route changes.
    @State private var scannerVM: ScannerViewModel?
    @State private var reconcileVM: ReconcileViewModel?

    private var routeBinding: Binding<NavigationItem> {
        Binding(
            get: { route },
            set: { newValue in
                if newValue != route && navigationGuard.hasUnsavedChanges {
                    pendingRoute = newValue
                    showLeaveAlert = true
                } else {
                    navigationGuard.clearDirty()
                    route = newValue
                }
            }
        )
    }

    var body: some View {
        HStack(spacing: 0) {
            if showSidebar {
                SidebarView(selectedItem: routeBinding)
                    .frame(width: 240)
                    .transition(.move(edge: .leading))
            }

            VStack(spacing: 0) {
                headerBar
                contentArea
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .environment(\.navigationGuard, navigationGuard)
        .appBackground()
        .frame(minWidth: 1000, minHeight: 700)
        .preferredColorScheme(resolvedColorScheme)
        .alert("Leave without saving?", isPresented: $showLeaveAlert) {
            Button("Keep Editing", role: .cancel) { pendingRoute = nil }
            Button("Discard and leave", role: .destructive) {
                navigationGuard.performDiscard()
                if let next = pendingRoute { route = next }
                pendingRoute = nil
            }
        } message: {
            Text("Your changes will not be saved.")
        }
        // RFID assign sheet
        .sheet(isPresented: Binding(
            get: { rfidCoordinator?.showAssignSheet ?? false },
            set: { if !$0 { rfidCoordinator?.dismissAssignSheet() } }
        )) {
            if let coord = rfidCoordinator {
                UnknownTagAssignSheet(epc: coord.pendingEpc, tid: coord.pendingTid)
            }
        }
        // Keyboard shortcuts for navigation
        .background {
            Group {
                Button("") { routeBinding.wrappedValue = .dashboard }.keyboardShortcut("1", modifiers: .command)
                Button("") { routeBinding.wrappedValue = .memos }.keyboardShortcut("2", modifiers: .command)
                Button("") { routeBinding.wrappedValue = .invoices }.keyboardShortcut("3", modifiers: .command)
                Button("") { routeBinding.wrappedValue = .customers }.keyboardShortcut("4", modifiers: .command)
                Button("") { routeBinding.wrappedValue = .inventory }.keyboardShortcut("5", modifiers: .command)
                Button("") { routeBinding.wrappedValue = .quickIntake }.keyboardShortcut("6", modifiers: .command)
                Button("") { routeBinding.wrappedValue = .reviewQueue }.keyboardShortcut("7", modifiers: .command)
                Button("") { routeBinding.wrappedValue = .accounting }.keyboardShortcut("8", modifiers: .command)
                Button("") { routeBinding.wrappedValue = .lots }.keyboardShortcut("9", modifiers: .command)
            }
            .frame(width: 0, height: 0).opacity(0)
        }
        .onAppear { createSharedVMs() }
        .onChange(of: rfidCoordinator != nil) { _, isNonNil in
            if isNonNil { createSharedVMs() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .menuNewMemo)) { _ in
            routeBinding.wrappedValue = .memos
        }
        .onReceive(NotificationCenter.default.publisher(for: .menuNewInvoice)) { _ in
            routeBinding.wrappedValue = .invoices
        }
        .onReceive(NotificationCenter.default.publisher(for: .menuNewStone)) { _ in
            routeBinding.wrappedValue = .quickIntake
        }
        .onReceive(NotificationCenter.default.publisher(for: .menuToggleSidebar)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) { showSidebar.toggle() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .menuOpenSettings)) { _ in
            routeBinding.wrappedValue = .settings
        }
        .animation(.easeInOut(duration: 0.2), value: showSidebar)
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(route.rawValue)
                    .font(AppTypography.subheading)
                    .foregroundStyle(AppColors.ink)
                    .tracking(0.3)
                Text("QDI Gemstone ERP")
                    .font(AppTypography.sectionLabel)
                    .foregroundStyle(AppColors.inkSubtle)
            }
            Spacer()
            HStack(spacing: AppSpacing.cozy) {
                Button(action: {}) {
                    Image(systemName: "bell")
                        .font(.system(size: 14))
                        .foregroundStyle(AppColors.inkSubtle)
                        .frame(width: 36, height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: AppCornerRadius.m, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppCornerRadius.m, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Notifications")

                ZStack {
                    RoundedRectangle(cornerRadius: AppCornerRadius.m, style: .continuous)
                        .fill(AppColors.primaryGradient)
                        .frame(width: 36, height: 36)
                        .shadow(color: AppColors.primary.opacity(0.20), radius: 6, y: 2)
                    Text("Q")
                        .font(AppTypography.body.weight(.semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(.horizontal, AppSpacing.section)
        .padding(.vertical, AppSpacing.standard)
    }

    // MARK: - Content Router

    private var contentArea: some View {
        Group {
            switch route {
            case .dashboard:
                DashboardView(navigateTo: routeBinding)
            case .inventory:
                InventoryListView(navigateTo: routeBinding, mode: .current)
            case .lots:
                LotInventoryView()
            case .soldInventory:
                InventoryListView(navigateTo: routeBinding, mode: .sold)
            case .quickIntake:
                StoneFormView(mode: .intake)
            case .reviewQueue:
                ReviewQueueView()
            case .scanner:
                if let vm = scannerVM { ScannerView(viewModel: vm) }
            case .reconcile:
                if let vm = reconcileVM { ReconcileView(viewModel: vm) }
            case .memos:
                MemoListView()
            case .invoices:
                InvoiceListView()
            case .customers:
                CustomerListView()
            case .accounting:
                AccountingView()
            case .settings:
                CompanySettingsView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.l, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: AppCornerRadius.l, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.l, style: .continuous))
        .padding(.horizontal, AppSpacing.standard)
        .padding(.bottom, AppSpacing.standard)
    }

    private func createSharedVMs() {
        if let coord = rfidCoordinator {
            if scannerVM == nil {
                scannerVM = ScannerViewModel(rfidService: coord.rfidService, rfidCoordinator: coord)
            }
            if reconcileVM == nil {
                reconcileVM = ReconcileViewModel(rfidService: coord.rfidService, rfidCoordinator: coord)
            }
        }
    }
}
