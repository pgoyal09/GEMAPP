import SwiftUI

extension GemstoneStatus {
    /// Canonical `StatusBadge` for this status, shared across all inventory views.
    var badge: StatusBadge {
        switch self {
        case .available:    return StatusBadge(title: "Available", tone: .success)
        case .onMemo:       return StatusBadge(title: "On Memo", tone: .warning)
        case .sold:         return StatusBadge(title: "Sold", tone: .accent)
        case .atLab:        return StatusBadge(title: "At Lab", tone: .info)
        case .reserved:     return StatusBadge(title: "Reserved", tone: .danger)
        case .inTransit:    return StatusBadge(title: "In Transit", tone: .violet)
        case .consignment:  return StatusBadge(title: "Consignment", tone: .neutral)
        }
    }
}
