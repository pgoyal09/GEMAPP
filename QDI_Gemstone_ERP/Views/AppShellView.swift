import SwiftUI
import SwiftData

/// Stable app shell: fixed sidebar + main content. No NavigationSplitView — uses plain HStack
/// so no page can affect global layout or sidebar width.
struct AppShellView: View {
    @EnvironmentObject private var rfidManager: RFIDManager
    @Environment(\.rfidCoordinator) private var rfidCoordinator
    @State private var route: NavigationItem = .dashboard
    @State private var pendingRoute: NavigationItem?
    @State private var showLeaveWithoutSavingAlert = false
    @State private var navigationGuard = NavigationGuard()
    @State private var scannerViewModel: ScannerViewModel?
    @State private var reconcileViewModel: ReconcileViewModel?

    private var routeBinding: Binding<NavigationItem> {
        Binding(
            get: { route },
            set: { newValue in
                if newValue != route && navigationGuard.hasUnsavedChanges {
                    pendingRoute = newValue
                    showLeaveWithoutSavingAlert = true
                } else {
                    navigationGuard.clearDirty()
                    route = newValue
                }
            }
        )
    }

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(selectedItem: routeBinding)
                .frame(width: 240)

            VStack(spacing: 0) {
                // Top header bar
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(route.rawValue)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.90))
                            .tracking(0.3)
                        Text("QDI Gemstone ERP")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.white.opacity(0.30))
                    }
                    Spacer()
                    HStack(spacing: 12) {
                        Button(action: {}) {
                            Image(systemName: "bell")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.white.opacity(0.40))
                                .frame(width: 36, height: 36)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.white.opacity(0.06))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                                        )
                                )
                        }
                        .buttonStyle(.plain)

                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(AppColors.primaryGradient)
                                .frame(width: 36, height: 36)
                                .shadow(color: AppColors.primary.opacity(0.20), radius: 6, y: 2)
                            Text("Q")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)

                // Main content in glass container
                Group {
                    switch route {
                    case .dashboard:
                        DashboardView(selectedNavigationItem: $route)
                    case .inventory:
                        InventoryListView(selectedNavigationItem: $route, mode: .current)
                    case .lots:
                        LotInventoryView(selectedNavigationItem: $route)
                    case .soldInventory:
                        InventoryListView(selectedNavigationItem: $route, mode: .sold)
                    case .quickIntake:
                        QuickIntakeView()
                    case .reviewQueue:
                        ReviewQueueView()
                    case .scanner:
                        ScannerView(viewModel: scannerViewModel ?? ScannerViewModel(rfidService: rfidManager, rfidCoordinator: rfidCoordinator))
                    case .reconcile:
                        InventoryReconcileView(viewModel: reconcileViewModel ?? ReconcileViewModel(rfidService: rfidManager, rfidCoordinator: rfidCoordinator))
                    case .memos:
                        MemosView()
                    case .invoices:
                        InvoiceListView()
                    case .customers:
                        CustomerListView()
                    case .accounting:
                        AccountingView()
                    case .inventoryAging:
                        InventoryAgingView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .environment(\.navigationGuard, navigationGuard)
        .background(AppColors.shellGradient)
        .alert("Leave without saving?", isPresented: $showLeaveWithoutSavingAlert) {
            Button("Keep Editing", role: .cancel) {
                pendingRoute = nil
            }
            Button("Discard edits and leave", role: .destructive) {
                navigationGuard.performDiscard()
                if let next = pendingRoute {
                    route = next
                }
                pendingRoute = nil
            }
        } message: {
            Text("Your changes will not be saved.")
        }
        .frame(minWidth: 1000, minHeight: 700)
        .preferredColorScheme(.dark)
        .environment(\.rfidService, rfidManager)
        // MARK: - Navigation keyboard shortcuts
        .background {
            Group {
                Button("") { routeBinding.wrappedValue = .dashboard }
                    .keyboardShortcut("1", modifiers: .command)
                Button("") { routeBinding.wrappedValue = .memos }
                    .keyboardShortcut("2", modifiers: .command)
                Button("") { routeBinding.wrappedValue = .invoices }
                    .keyboardShortcut("3", modifiers: .command)
                Button("") { routeBinding.wrappedValue = .customers }
                    .keyboardShortcut("4", modifiers: .command)
                Button("") { routeBinding.wrappedValue = .inventory }
                    .keyboardShortcut("5", modifiers: .command)
                Button("") { routeBinding.wrappedValue = .quickIntake }
                    .keyboardShortcut("6", modifiers: .command)
                Button("") { routeBinding.wrappedValue = .reviewQueue }
                    .keyboardShortcut("7", modifiers: .command)
                Button("") { routeBinding.wrappedValue = .accounting }
                    .keyboardShortcut("8", modifiers: .command)
                Button("") { routeBinding.wrappedValue = .lots }
                    .keyboardShortcut("9", modifiers: .command)
            }
            .frame(width: 0, height: 0)
            .opacity(0)
        }
        .sheet(isPresented: Binding(
            get: { rfidCoordinator?.showAssignModal ?? false },
            set: { if !$0 { rfidCoordinator?.dismissAssignSheet() } }
        )) {
            if let tag = rfidCoordinator?.pendingUnknownTag {
                UnknownTagAssignSheet(epc: tag.epc, tid: tag.tid) {
                    rfidCoordinator?.dismissAssignSheet()
                } onAssigned: { stone in
                    rfidCoordinator?.reportAssignSuccess(sku: stone.sku)
                }
            }
        }
        .overlay {
            if let msg = rfidCoordinator?.assignSuccessMessage {
                VStack {
                    Spacer()
                    AppStatusBadge(title: msg, tone: .success)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(AppColors.cardElevated)
                        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.m, style: .continuous))
                        .padding(.bottom, 24)
                }
                .transition(.move(edge: .bottom))
            }
        }
        .onAppear {
            if scannerViewModel == nil {
                scannerViewModel = ScannerViewModel(rfidService: rfidManager, rfidCoordinator: rfidCoordinator)
            }
            if reconcileViewModel == nil {
                reconcileViewModel = ReconcileViewModel(rfidService: rfidManager, rfidCoordinator: rfidCoordinator)
            }
        }
    }
}
