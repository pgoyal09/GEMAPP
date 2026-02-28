import Foundation

/// Coordinates RFID scan results and unknown-tag assignment. Holds pending unknown tag state for the assign sheet.
@MainActor
@Observable
final class RFIDCoordinator {
    /// Unknown tag to assign; when non-nil and showAssignModal, present UnknownTagAssignSheet.
    var pendingUnknownTag: (epc: String, tid: String?)?

    /// Whether to show the assign tag modal.
    var showAssignModal: Bool = false

    /// Brief success message after assignment (e.g. "Assigned to SKU-001").
    var assignSuccessMessage: String?

    /// Present the unknown-tag assign sheet for the given EPC (and optional TID).
    func presentAssignSheet(epc: String, tid: String?) {
        pendingUnknownTag = (epc, tid)
        showAssignModal = true
    }

    /// Dismiss the assign sheet and clear pending state.
    func dismissAssignSheet() {
        showAssignModal = false
        pendingUnknownTag = nil
    }

    /// Report assignment success and auto-clear message after delay.
    func reportAssignSuccess(sku: String) {
        assignSuccessMessage = "Assigned to \(sku)"
        dismissAssignSheet()
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            assignSuccessMessage = nil
        }
    }
}
