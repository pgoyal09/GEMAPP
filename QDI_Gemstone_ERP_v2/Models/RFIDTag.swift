import Foundation
import SwiftData

@Model
final class RFIDTag {
    @Attribute(.unique) var epcCurrent: String
    var tidLastVerified: String?
    var status: RFIDLifecycleStatus
    var firstSeenAt: Date?
    var lastSeenAt: Date?
    var lastVerifiedAt: Date?
    var printerJobID: String?
    var notes: String?

    var assignedStone: Gemstone?

    init(
        epcCurrent: String,
        tidLastVerified: String? = nil,
        assignedStone: Gemstone? = nil,
        status: RFIDLifecycleStatus = .unassigned,
        firstSeenAt: Date? = nil,
        lastSeenAt: Date? = nil,
        lastVerifiedAt: Date? = nil,
        printerJobID: String? = nil,
        notes: String? = nil
    ) {
        self.epcCurrent = epcCurrent
        self.tidLastVerified = tidLastVerified
        self.assignedStone = assignedStone
        self.status = status
        self.firstSeenAt = firstSeenAt
        self.lastSeenAt = lastSeenAt
        self.lastVerifiedAt = lastVerifiedAt
        self.printerJobID = printerJobID
        self.notes = notes
    }
}
