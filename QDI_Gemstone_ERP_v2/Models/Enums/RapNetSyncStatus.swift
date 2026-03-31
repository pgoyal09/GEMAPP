import Foundation

enum RapNetSyncStatus: String, Codable, CaseIterable {
    case notSynced = "notSynced"
    case synced = "synced"
    case pending = "pending"
    case error = "error"

    var displayName: String {
        switch self {
        case .notSynced: return "Not Synced"
        case .synced: return "Synced"
        case .pending: return "Pending"
        case .error: return "Error"
        }
    }

    var icon: String {
        switch self {
        case .notSynced: return "minus.circle"
        case .synced: return "checkmark.circle.fill"
        case .pending: return "arrow.triangle.2.circlepath"
        case .error: return "exclamationmark.triangle.fill"
        }
    }
}
