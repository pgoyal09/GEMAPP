import Foundation

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

    var icon: String {
        switch self {
        case .dashboard:     return "chart.bar.fill"
        case .inventory:     return "square.grid.2x2.fill"
        case .lots:          return "cube.box.fill"
        case .soldInventory: return "tag.fill"
        case .quickIntake:   return "plus.circle.fill"
        case .reviewQueue:   return "list.bullet.clipboard"
        case .scanner:       return "antenna.radiowaves.left.and.right"
        case .reconcile:     return "checkmark.circle"
        case .memos:         return "doc.text.fill"
        case .invoices:      return "dollarsign.circle.fill"
        case .customers:     return "person.2.fill"
        case .accounting:    return "chart.pie.fill"
        }
    }

    static let groups: [(label: String, items: [NavigationItem])] = [
        ("Get Started", [.dashboard, .scanner]),
        ("Sales", [.memos, .invoices, .customers]),
        ("Accounting", [.accounting]),
        ("Inventory", [.inventory, .lots, .soldInventory, .quickIntake, .reviewQueue, .reconcile]),
    ]
}
