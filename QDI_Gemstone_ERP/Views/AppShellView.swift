import SwiftUI
import SwiftData

/// Stable app shell: fixed sidebar + main content. No NavigationSplitView — uses plain HStack
/// so no page can affect global layout or sidebar width.
struct AppShellView: View {
    @EnvironmentObject private var rfidManager: RFIDManager
    @Environment(\.rfidCoordinator) private var rfidCoordinator
    @State private var route: NavigationItem = .dashboard
    @State private var scannerViewModel: ScannerViewModel?
    @State private var reconcileViewModel: ReconcileViewModel?

    var body: some View {
        HStack(spacing: 0) {
            // Left: fixed-width sidebar (never resizable)
            SidebarView(selectedItem: $route)
                .frame(width: 240)
                .background(AppColors.cardBackground)

            Divider()

            // Right: main content (pages are self-contained; cannot affect sidebar)
            Group {
                switch route {
                case .dashboard:
                    DashboardView(selectedNavigationItem: $route)
                case .inventory:
                    InventoryListView(selectedNavigationItem: $route)
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
                    Text(msg)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.green)
                        .cornerRadius(8)
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
