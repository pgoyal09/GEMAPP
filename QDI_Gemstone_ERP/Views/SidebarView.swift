import SwiftUI

enum NavigationItem: String, CaseIterable {
    case dashboard = "Dashboard"
    case inventory = "Single & Pair Inventory"
    case lots = "Lot Inventory"
    case soldInventory = "Sold Inventory"
    case quickIntake = "Quick Intake"
    case reviewQueue = "Review Queue"
    case scanner = "Scanner"
    case reconcile = "Reconcile"
    case memos = "Memos"
    case invoices = "Invoices"
    case customers = "Customers"
    case accounting = "Accounting"
    case inventoryAging = "Inventory Aging"
}

struct SidebarView: View {
    @Binding var selectedItem: NavigationItem

    private let navGroups: [(label: String, items: [NavigationItem])] = [
        ("Get Started", [.dashboard, .scanner]),
        ("Sales", [.memos, .invoices, .customers]),
        ("Accounting", [.accounting]),
        ("Inventory", [.inventory, .lots, .soldInventory, .quickIntake, .reviewQueue, .reconcile, .inventoryAging]),
    ]

    var body: some View {
        VStack(spacing: 0) {
            sidebarHeader

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(navGroups, id: \.label) { group in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(group.label.uppercased())
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.30))
                                .tracking(1.5)
                                .padding(.horizontal, 12)
                                .padding(.bottom, 4)

                            ForEach(group.items, id: \.self) { item in
                                sidebarRow(item)
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 16)
            }

            Spacer(minLength: 0)

            // Settings placeholder
            HStack(spacing: 10) {
                Image(systemName: "gearshape")
                    .font(.system(size: 14))
                Text("Settings")
                    .font(.system(size: 13))
            }
            .foregroundStyle(Color.white.opacity(0.40))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .top) {
                Divider().background(Color.white.opacity(0.06))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
                .padding(8)
        )
        .background(Color.clear)
    }

    private var sidebarHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(AppColors.primaryGradient)
                    .frame(width: 36, height: 36)
                    .shadow(color: AppColors.primary.opacity(0.20), radius: 6, y: 2)
                Image(systemName: "diamond.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("QDI Gemstone")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.90))
                    .tracking(0.3)
                Text("ERP · RFID Studio")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.40))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
        .overlay(alignment: .bottom) {
            Divider().background(Color.white.opacity(0.06))
        }
    }

    private func sidebarRow(_ item: NavigationItem) -> some View {
        let isActive = selectedItem == item
        return Button {
            selectedItem = item
        } label: {
            HStack(spacing: 10) {
                Image(systemName: iconFor(item))
                    .font(.system(size: 14))
                    .frame(width: 16)
                Text(item.rawValue)
                    .font(.system(size: 13))
            }
            .foregroundStyle(isActive ? AppColors.primary : Color.white.opacity(0.50))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Group {
                    if isActive {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(AppColors.primary.opacity(0.12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(AppColors.primary.opacity(0.20), lineWidth: 1)
                            )
                    }
                }
            )
            .animation(AppAnimation.tabSwitch, value: isActive)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .tag(item)
    }

    private func iconFor(_ item: NavigationItem) -> String {
        switch item {
        case .dashboard: return "chart.bar.fill"
        case .inventory: return "square.grid.2x2.fill"
        case .lots: return "cube.box.fill"
        case .soldInventory: return "tag.fill"
        case .quickIntake: return "plus.circle.fill"
        case .reviewQueue: return "list.bullet.clipboard"
        case .scanner: return "antenna.radiowaves.left.and.right"
        case .reconcile: return "checkmark.circle"
        case .memos: return "doc.text.fill"
        case .invoices: return "dollarsign.circle.fill"
        case .customers: return "person.2.fill"
        case .accounting: return "chart.pie.fill"
        case .inventoryAging: return "clock.arrow.circlepath"
        }
    }
}
