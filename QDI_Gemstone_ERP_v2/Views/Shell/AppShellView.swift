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
    @AppStorage("appAppearance") private var appAppearance: String = "dark"
    @AppStorage("onboardingComplete") private var onboardingComplete: Bool = false
    @AppStorage("companyName") private var companyName: String = ""
    @State private var showGlossary = false
    @State private var showHelpCenter = false
    @State private var showNotifications = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var resolvedColorScheme: ColorScheme? {
        switch appAppearance {
        case "light": return .light
        case "dark": return .dark
        default: return nil
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
        .background(AppColors.background)
        .frame(minWidth: 1100, minHeight: 700)
        .accessibilityIdentifier("AppShellView")
        .preferredColorScheme(resolvedColorScheme)
        .sheet(isPresented: $showGlossary) {
            GlossaryView()
        }
        .sheet(isPresented: $showHelpCenter) {
            HelpCenterView()
        }
    }

    private var sidebarTransition: AnyTransition {
        reduceMotion ? .opacity : .move(edge: .leading)
    }

    private var mainContent: some View {
        HStack(spacing: 0) {
            if showSidebar {
                SidebarView(selectedItem: routeBinding)
                    .frame(width: 220)
                    .fixedSize(horizontal: true, vertical: false)
                    .layoutPriority(1)
                    .transition(sidebarTransition)
            }

            VStack(spacing: 0) {
                headerBar
                contentArea
            }
            .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
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
        .sheet(isPresented: Binding<Bool>(
            get: { rfidCoordinator?.showAssignSheet ?? false },
            set: { newValue in if !newValue { rfidCoordinator?.dismissAssignSheet() } }
        )) {
            if let coord = rfidCoordinator {
                UnknownTagAssignSheet(epc: coord.pendingEpc, tid: coord.pendingTid)
            }
        }
        // Keyboard shortcuts: ⌘1-⌘8 match spec, ⌘0 = Scanner, ⌘, = Settings
        .background {
            Group {
                Button("") { routeBinding.wrappedValue = .dashboard }.keyboardShortcut("1", modifiers: .command)
                Button("") { routeBinding.wrappedValue = .memos }.keyboardShortcut("2", modifiers: .command)
                Button("") { routeBinding.wrappedValue = .invoices }.keyboardShortcut("3", modifiers: .command)
                Button("") { routeBinding.wrappedValue = .customers }.keyboardShortcut("4", modifiers: .command)
                Button("") { routeBinding.wrappedValue = .diamonds }.keyboardShortcut("5", modifiers: .command)
                Button("") { routeBinding.wrappedValue = .gemstones }.keyboardShortcut("6", modifiers: .command)
                Button("") { routeBinding.wrappedValue = .lots }.keyboardShortcut("7", modifiers: .command)
                Button("") { routeBinding.wrappedValue = .sold }.keyboardShortcut("8", modifiers: .command)
                Button("") { routeBinding.wrappedValue = .quickIntake }.keyboardShortcut("9", modifiers: .command)
                Button("") { routeBinding.wrappedValue = .scanner }.keyboardShortcut("0", modifiers: .command)
                // Removed: global Escape capture was breaking sheet/alert/popover dismissal
                // Individual views handle Escape via onKeyPress(.escape) where appropriate
            }
            .frame(width: 0, height: 0).opacity(0)
        }
        .onAppear { createSharedVMs() }
        .onChange(of: rfidCoordinator != nil) { _, isNonNil in
            if isNonNil { createSharedVMs() }
        }
        .modifier(MenuCommandReceiver(
            routeBinding: routeBinding,
            route: route,
            showSidebar: $showSidebar,
            showGlossary: $showGlossary,
            showHelpCenter: $showHelpCenter,
            reduceMotion: reduceMotion
        ))
        .animation(reduceMotion ? nil : AppAnimation.standard, value: showSidebar)
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Text(route.rawValue)
                .font(AppTypography.subheading)
                .foregroundStyle(AppColors.ink)
                .tracking(0.3)
            Spacer()
            HStack(spacing: AppSpacing.comfortable) {
                Button { showNotifications.toggle() } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bell")
                            .font(AppTypography.body)
                            .foregroundStyle(AppColors.inkSubtle)
                            .frame(width: 36, height: 36)
                            .background(
                                RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                                    .fill(AppColors.cardElevated)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                                            .strokeBorder(AppColors.cardStroke, lineWidth: 1)
                                    )
                            )
                        if !overdueMemos.isEmpty {
                            Text("\(min(overdueMemos.count, 9))\(overdueMemos.count > 9 ? "+" : "")")
                                .font(AppTypography.tinyLabel)
                                .foregroundStyle(.white)
                                .padding(.horizontal, AppSpacing.compact)
                                .padding(.vertical, 1)
                                .background(AppColors.danger)
                                .clipShape(Capsule())
                                .offset(x: AppSpacing.compact, y: -AppSpacing.compact)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(overdueMemos.isEmpty ? "Notifications" : "\(overdueMemos.count) overdue notifications")
                .popover(isPresented: $showNotifications, arrowEdge: .top) {
                    notificationPopoverContent
                }

                ZStack {
                    RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
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
        .frame(height: 56)
    }

    private var notificationPopoverContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.standard) {
            Text("Notifications")
                .font(AppTypography.caption.bold())
                .foregroundStyle(AppColors.ink)
            Divider()
            let overdue = overdueMemos
            if overdue.isEmpty {
                Text("No new notifications")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.inkSubtle)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.standard)
            } else {
                ForEach(overdue.prefix(5), id: \.persistentModelID) { memo in
                    HStack(spacing: AppSpacing.small) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.warningDeep)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Memo #\(memo.referenceNumber)")
                                .font(AppTypography.caption.weight(.medium))
                                .foregroundStyle(AppColors.ink)
                            let custName = memo.customer?.displayName ?? "Unknown"
                            Text("\(memo.ageInDays) days — \(custName)")
                                .font(AppTypography.sectionLabel)
                                .foregroundStyle(AppColors.inkSubtle)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
                if overdue.count > 5 {
                    Text("+\(overdue.count - 5) more overdue")
                        .font(AppTypography.sectionLabel)
                        .foregroundStyle(AppColors.inkMuted)
                }
            }
        }
        .padding()
        .frame(width: 300)
    }

    private var overdueMemos: [Memo] {
        // Fetch only what's needed — sort by createdAt ascending (oldest first) for age ordering
        let descriptor = FetchDescriptor<Memo>(sortBy: [SortDescriptor(\Memo.createdAt, order: .forward)])
        let all = (try? modelContext.fetch(descriptor)) ?? []
        return all.filter { $0.status == .onMemo && $0.ageInDays > 60 }
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
            case .accountsReceivable:
                ARDashboardView()
            case .memoReturn:
                MemoReturnScanView()
            case .settings:
                CompanySettingsView()
            }
        }
        .transition(reduceMotion ? .opacity : .asymmetric(
            insertion: .opacity.combined(with: .offset(x: 20)),
            removal: .opacity
        ))
        .animation(reduceMotion ? nil : AppAnimation.standard, value: route)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                .fill(AppColors.panelBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                        .strokeBorder(AppColors.cardStroke, lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous))
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

// MARK: - Menu Command Receiver (extracted to fix type-checker timeout)

private struct MenuCommandReceiver: ViewModifier {
    let routeBinding: Binding<NavigationItem>
    let route: NavigationItem
    @Binding var showSidebar: Bool
    @Binding var showGlossary: Bool
    @Binding var showHelpCenter: Bool
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .menuNewMemo)) { _ in routeBinding.wrappedValue = .memos }
            .onReceive(NotificationCenter.default.publisher(for: .menuNewInvoice)) { _ in routeBinding.wrappedValue = .invoices }
            .onReceive(NotificationCenter.default.publisher(for: .menuNewStone)) { _ in routeBinding.wrappedValue = .quickIntake }
            .onReceive(NotificationCenter.default.publisher(for: .menuNewDiamond)) { _ in routeBinding.wrappedValue = .quickIntake }
            .onReceive(NotificationCenter.default.publisher(for: .menuNewGemstone)) { _ in routeBinding.wrappedValue = .quickIntake }
            .onReceive(NotificationCenter.default.publisher(for: .menuNewLot)) { _ in routeBinding.wrappedValue = .quickIntake }
            .onReceive(NotificationCenter.default.publisher(for: .menuToggleSidebar)) { _ in
                if reduceMotion { showSidebar.toggle() }
                else { withAnimation(.easeInOut(duration: 0.2)) { showSidebar.toggle() } }
            }
            .onReceive(NotificationCenter.default.publisher(for: .menuOpenSettings)) { _ in routeBinding.wrappedValue = .settings }
            .onReceive(NotificationCenter.default.publisher(for: .menuOpenGlossary)) { _ in showGlossary = true }
            .onReceive(NotificationCenter.default.publisher(for: .menuOpenHelpCenter)) { _ in showHelpCenter = true }
            .modifier(MenuCommandReceiverPart2(routeBinding: routeBinding, route: route))
    }
}

private struct MenuCommandReceiverPart2: ViewModifier {
    let routeBinding: Binding<NavigationItem>
    let route: NavigationItem

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .menuContextNewItem)) { _ in
                switch route {
                case .memos: NotificationCenter.default.post(name: .menuNewMemo, object: nil)
                case .invoices: NotificationCenter.default.post(name: .menuNewInvoice, object: nil)
                default: routeBinding.wrappedValue = .quickIntake
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .menuQuickIntake)) { _ in routeBinding.wrappedValue = .quickIntake }
            .onReceive(NotificationCenter.default.publisher(for: .menuReviewQueue)) { _ in routeBinding.wrappedValue = .reviewQueue }
            .onReceive(NotificationCenter.default.publisher(for: .menuReconcile)) { _ in routeBinding.wrappedValue = .reconcile }
            .onReceive(NotificationCenter.default.publisher(for: .menuAgingReport)) { _ in routeBinding.wrappedValue = .accountsReceivable }
            .onReceive(NotificationCenter.default.publisher(for: .menuCloudBackup)) { _ in routeBinding.wrappedValue = .settings }
    }
}
