import SwiftUI

enum NavigationItem: String, CaseIterable {
    case dashboard = "Dashboard"
    case inventory = "Inventory"
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
                sidebarRow(.quickIntake)
                sidebarRow(.reviewQueue)
                sidebarRow(.reconcile)
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .top, spacing: 0) {
            sidebarHeader
        }
    }

    private var sidebarHeader: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("QDI Gemstone ERP")
                .font(.headline)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.m)
        .background(AppColors.cardBackground)
    }

    private func sidebarRow(_ item: NavigationItem) -> some View {
        Button {
            selectedItem = item
        } label: {
            Label(item.rawValue, systemImage: iconFor(item))
        }
        .buttonStyle(.plain)
        .tag(item)
    }

    private func iconFor(_ item: NavigationItem) -> String {
        switch item {
        case .dashboard: return "chart.bar.fill"
        case .inventory: return "square.grid.2x2.fill"
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
