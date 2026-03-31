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
    @AppStorage("onboardingComplete") private var onboardingComplete: Bool = false
    @AppStorage("companyName") private var companyName: String = ""
    @State private var showGlossary = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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

    private var needsOnboarding: Bool {
        !onboardingComplete && companyName.isEmpty
    }

    var body: some View {
        Group {
            if needsOnboarding {
                OnboardingView()
            } else {
                mainContent
            }
        }
        .environment(\.navigationGuard, navigationGuard)
        .appBackground()
        .frame(minWidth: 1000, minHeight: 700)
        .accessibilityIdentifier("AppShellView")
        .preferredColorScheme(resolvedColorScheme)
        .sheet(isPresented: $showGlossary) {
            GlossaryView()
        }
    }

    private var mainContent: some View {
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
                Button("") { routeBinding.wrappedValue = .diamonds }.keyboardShortcut("5", modifiers: .command)
                Button("") { routeBinding.wrappedValue = .gemstones }.keyboardShortcut("6", modifiers: .command)
                Button("") { routeBinding.wrappedValue = .lots }.keyboardShortcut("7", modifiers: .command)
                Button("") { routeBinding.wrappedValue = .accounting }.keyboardShortcut("8", modifiers: .command)
                Button("") { routeBinding.wrappedValue = .quickIntake }.keyboardShortcut("9", modifiers: .command)
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
        .onReceive(NotificationCenter.default.publisher(for: .menuNewDiamond)) { _ in
            routeBinding.wrappedValue = .quickIntake
        }
        .onReceive(NotificationCenter.default.publisher(for: .menuNewGemstone)) { _ in
            routeBinding.wrappedValue = .quickIntake
        }
        .onReceive(NotificationCenter.default.publisher(for: .menuNewLot)) { _ in
            routeBinding.wrappedValue = .quickIntake
        }
        .onReceive(NotificationCenter.default.publisher(for: .menuToggleSidebar)) { _ in
            if reduceMotion { showSidebar.toggle() }
            else { withAnimation(.easeInOut(duration: 0.2)) { showSidebar.toggle() } }
        }
        .onReceive(NotificationCenter.default.publisher(for: .menuOpenSettings)) { _ in
            routeBinding.wrappedValue = .settings
        }
        .onReceive(NotificationCenter.default.publisher(for: .menuOpenGlossary)) { _ in
            showGlossary = true
        }
        .animation(AppAnimation.standard, value: showSidebar)
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
            HStack(spacing: AppSpacing.comfortable) {
                Button(action: {}) {
                    Image(systemName: "bell")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.inkSubtle)
                        .frame(width: 36, height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: AppCornerRadius.large, style: .continuous)
                                .fill(AppColors.cardElevated)
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppCornerRadius.large, style: .continuous)
                                        .strokeBorder(AppColors.cardStroke, lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Notifications")

                ZStack {
                    RoundedRectangle(cornerRadius: AppCornerRadius.large, style: .continuous)
                        .fill(AppColors.primaryGradient)
                        .frame(width: 36, height: 36)
                        .shadow(color: AppColors.primary.opacity(AppOpacity.muted), radius: 6, y: 2)
                    Text("Q")
                        .font(AppTypography.body.weight(.semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(.horizontal, AppSpacing.hero)
        .padding(.vertical, AppSpacing.section)
    }

    // MARK: - Content Router

    private var contentArea: some View {
        Group {
            switch route {
            case .dashboard:
                DashboardView(navigateTo: routeBinding)
            case .diamonds:
                DiamondsInventoryView(navigateTo: routeBinding)
            case .gemstones:
                GemstonesInventoryView(navigateTo: routeBinding)
            case .lots:
                LotInventoryView()
            case .sold:
                SoldInventoryView()
            case .quickIntake:
                StoneFormView(mode: .intake, navigateTo: routeBinding)
            case .quickEntry:
                QuickEntryView()
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
            case .reports:
                ReportsView()
            case .settings:
                CompanySettingsView()
            }
        }
        .id(route)
        .transition(reduceMotion ? .opacity : .asymmetric(
            insertion: .opacity.combined(with: .offset(x: 20)),
            removal: .opacity
        ))
        .animation(reduceMotion ? nil : AppAnimation.standard, value: route)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.large, style: .continuous)
                .fill(AppColors.panelBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCornerRadius.large, style: .continuous)
                        .strokeBorder(AppColors.cardStroke, lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.large, style: .continuous))
        .padding(.horizontal, AppSpacing.section)
        .padding(.bottom, AppSpacing.section)
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
