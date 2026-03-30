import Foundation

/// Lifecycle status of a physical RFID tag, from procurement through retirement.
enum RFIDLifecycleStatus: String, Codable, CaseIterable {
    case unassigned = "unassigned"
    case pending = "pending"
    case printRequested = "print_requested"
    case printed = "printed"
    case encoded = "encoded"
    case verified = "verified"
    case assigned = "assigned"
    case failed = "failed"
    case retired = "retired"
}
