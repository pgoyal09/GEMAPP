import SwiftUI

enum NavigationItem: String, CaseIterable {
    case dashboard = "Dashboard"
    case inventory = "Current Inventory"
    case soldInventory = "Sold Inventory"
    case quickIntake = "Quick Intake"
    case reviewQueue = "Review Queue"
    case scanner = "Scanner"
    case reconcile = "Reconcile"
    case memos = "Memos"
    case invoices = "Invoices"
    case customers = "Customers"
}

struct SidebarView: View {
    @Binding var selectedItem: NavigationItem

    var body: some View {
        VStack(spacing: 0) {
            sidebarHeader
            List(selection: $selectedItem) {
                Section("Get Started") {
                    sidebarRow(.dashboard)
                    sidebarRow(.scanner)
                }
                Section("Sales") {
                    sidebarRow(.memos)
                    sidebarRow(.invoices)
                    sidebarRow(.customers)
                }
                Section("Inventory") {
                    sidebarRow(.inventory)
                    sidebarRow(.soldInventory)
                    sidebarRow(.quickIntake)
                    sidebarRow(.reviewQueue)
                    sidebarRow(.reconcile)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(AppColors.panelBackground)
        }
        .background(AppColors.panelBackground)
    }

    private var sidebarHeader: some View {
        AppSurfaceCard(padding: AppSpacing.m, accent: AppColors.primary) {
            Text("QDI Gemstone ERP")
                .font(AppTypography.heading)
                .foregroundStyle(AppColors.ink)
            Text("RFID Inventory Studio")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.inkSubtle)
        }
        .padding(AppSpacing.s)
    }

    private func sidebarRow(_ item: NavigationItem) -> some View {
        Button {
            selectedItem = item
        } label: {
            Label(item.rawValue, systemImage: iconFor(item))
                .font(AppTypography.body)
                .foregroundStyle(selectedItem == item ? AppColors.ink : AppColors.inkMuted)
                .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
        .tag(item)
    }

    private func iconFor(_ item: NavigationItem) -> String {
        switch item {
        case .dashboard: return "chart.bar.fill"
        case .inventory: return "square.grid.2x2.fill"
        case .soldInventory: return "tag.fill"
        case .quickIntake: return "plus.circle.fill"
        case .reviewQueue: return "list.bullet.clipboard"
        case .scanner: return "antenna.radiowaves.left.and.right"
        case .reconcile: return "checkmark.circle"
        case .memos: return "doc.text.fill"
        case .invoices: return "dollarsign.circle.fill"
        case .customers: return "person.2.fill"
        }
    }
}
