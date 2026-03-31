import Foundation

enum NavigationItem: String, CaseIterable {
    case dashboard = "Dashboard"
    case diamonds = "Diamonds"
    case gemstones = "Gemstones"
    case lots = "Lots"
    case sold = "Sold"
    case quickIntake = "Quick Intake"
    case quickEntry = "Quick Entry"
    case reviewQueue = "Review Queue"
    case scanner = "Scanner"
    case reconcile = "Reconcile"
    case memos = "Memos"
    case invoices = "Invoices"
    case customers = "Customers"
    case accounting = "Accounting"
    case reports = "Reports"
    case settings = "Settings"

    var icon: String {
        switch self {
        case .dashboard:  return "chart.bar.fill"
        case .diamonds:   return "sparkle"
        case .gemstones:  return "aqi.medium"
        case .lots:       return "cube.box.fill"
        case .sold:       return "tag.fill"
        case .quickIntake: return "plus.circle.fill"
        case .quickEntry: return "tablecells.fill"
        case .reviewQueue: return "list.bullet.clipboard"
        case .scanner:    return "antenna.radiowaves.left.and.right"
        case .reconcile:  return "checkmark.circle"
        case .memos:      return "doc.text.fill"
        case .invoices:   return "dollarsign.circle.fill"
        case .customers:  return "person.2.fill"
        case .accounting: return "chart.pie.fill"
        case .reports:    return "chart.bar.xaxis"
        case .settings:   return "gearshape.fill"
        }
    }

    static let groups: [(label: String, items: [NavigationItem])] = [
        ("Get Started", [.dashboard, .scanner]),
        ("Sales", [.memos, .invoices, .customers]),
        ("Accounting", [.accounting, .reports]),
        ("Inventory", [.diamonds, .gemstones, .lots, .sold, .quickIntake, .quickEntry, .reviewQueue, .reconcile]),
        ("System", [.settings]),
    ]
}
