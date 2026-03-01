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
            // Left: fixed-width sidebar (never resizable)
            SidebarView(selectedItem: routeBinding)
                .frame(width: 240)
                .background(AppColors.panelBackground)

            Divider()

            // Right: main content (pages are self-contained; cannot affect sidebar)
            Group {
                switch route {
                case .dashboard:
                    DashboardView(selectedNavigationItem: $route)
                case .inventory:
                    InventoryListView(selectedNavigationItem: $route, mode: .current)
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
                }
            }
             .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .environment(\.navigationGuard, navigationGuard)
        .background(AppColors.shellGradient)
        .alert("Leave without saving?", isPresented: $showLeaveWithoutSavingAlert) {
            Button("Keep Editing", role: .cancel) {
                pendingRoute = nil
            }
            Button("Discard", role: .destructive) {
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
        .environment(\.rfidService, rfidManager)
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
