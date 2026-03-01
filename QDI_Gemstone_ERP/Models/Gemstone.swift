import Foundation
import SwiftData

/// Inventory status for strict control: picker shows only .available; save flows set .onMemo / .sold.
enum GemstoneStatus: String, Codable, CaseIterable {
    case available = "Available"
    case onMemo = "On Memo"
    case sold = "Sold"
}

@Model
final class Gemstone {
    var sku: String
    var stoneType: StoneType
    var caratWeight: Double
    var color: String
    var clarity: String
    var cut: String
    var origin: String
    var costPrice: Decimal
    var sellPrice: Decimal
    var createdAt: Date
    
    /// RFID tag ID for scanner lookup (e.g. GoToTags E310). Optional for existing records.
    /// @deprecated Prefer rfidEpc for new assignments. Kept for backward compatibility.
    var rfidTag: String?

    /// RFID EPC (Electronic Product Code) - stable tag identity. Unique when present.
    var rfidEpc: String?
    /// RFID TID (Tag Identifier) - manufacturer identity. Unique when present.
    var rfidTid: String?
    /// When this tag was assigned to this stone.
    var rfidAssignedAt: Date?
    /// Last time this tag was seen by the scanner.
    var rfidLastSeenAt: Date?
    /// "unassigned" | "assigned" - null until first assignment.
    var rfidStatus: String?

    /// Migration: optional so existing rows without status default to .available in code.
    var status: GemstoneStatus?
    
    var memo: Memo?

    @Relationship(inverse: \RFIDTag.assignedStone)
    var rfidTags: [RFIDTag] = []
    
    /// Quick Intake / Review Queue: optional extended fields
    var shape: String?
    var treatment: String?
    var hasCert: Bool?
    var grouping: String?
    var certLab: String?
    var certNo: String?
    var length: Double?
    var width: Double?
    var height: Double?
    /// Second stone dimensions for Pair grouping
    var length2: Double?
    var width2: Double?
    var height2: Double?
    var polish: String?
    var symmetry: String?
    var fluorescence: String?
    
    /// Path/URL reference to certificate image file.
    var certificateImagePath: String?
    /// JSON-encoded array of file paths for media assets.
    var mediaPathsJson: String?
    
    @Relationship(inverse: \HistoryEvent.gemstone)
    var events: [HistoryEvent] = []
    
    init(
        sku: String,
        stoneType: StoneType,
        caratWeight: Double,
        color: String,
        clarity: String,
        cut: String,
        origin: String,
        costPrice: Decimal,
        sellPrice: Decimal,
        createdAt: Date = Date(),
        rfidTag: String? = nil,
        status: GemstoneStatus = .available,
        shape: String? = nil,
        treatment: String? = nil,
        hasCert: Bool? = nil,
        grouping: String? = nil,
        certLab: String? = nil,
        certNo: String? = nil,
        length: Double? = nil,
        width: Double? = nil,
        height: Double? = nil,
        length2: Double? = nil,
        width2: Double? = nil,
        height2: Double? = nil,
        polish: String? = nil,
        symmetry: String? = nil,
        fluorescence: String? = nil
    ) {
        self.sku = sku
        self.stoneType = stoneType
        self.caratWeight = caratWeight
        self.color = color
        self.clarity = clarity
        self.cut = cut
        self.origin = origin
        self.costPrice = costPrice
        self.sellPrice = sellPrice
        self.createdAt = createdAt
        self.rfidTag = rfidTag
        self.status = status
        self.shape = shape
        self.treatment = treatment
        self.hasCert = hasCert
        self.grouping = grouping
        self.certLab = certLab
        self.certNo = certNo
        self.length = length
        self.width = width
        self.height = height
        self.length2 = length2
        self.width2 = width2
        self.height2 = height2
        self.polish = polish
        self.symmetry = symmetry
        self.fluorescence = fluorescence
    }
    
    /// Use in UI and filters; existing stones without status count as .available.
    var effectiveStatus: GemstoneStatus {
        status ?? .available
    }

    /// Review Queue: missing flags derived from optional fields
    var missingDimensions: Bool { length == nil || width == nil || height == nil }
    var missingCertDetails: Bool { (hasCert == true) && (certLab == nil || certLab?.isEmpty == true || certNo == nil || certNo?.isEmpty == true) }
    var missingCost: Bool { costPrice == 0 }
    var missingSellPrice: Bool { sellPrice == 0 }
    var missingDiamondGrading: Bool {
        stoneType == .diamond && (color.isEmpty || clarity.isEmpty || cut.isEmpty ||
            (polish ?? "").isEmpty || (symmetry ?? "").isEmpty || (fluorescence ?? "").isEmpty)
    }
    var needsReview: Bool {
        missingDimensions || missingCertDetails || missingCost || missingSellPrice || missingDiamondGrading
    }
    
    /// Effective EPC for lookup: rfidEpc takes precedence; rfidTag used for backward compat.
    var effectiveRfidEpc: String? { rfidEpc ?? rfidTag }

    /// Decoded media file paths from mediaPathsJson.
    var mediaPaths: [String] {
        get {
            guard let data = mediaPathsJson?.data(using: .utf8),
                  let arr = try? JSONDecoder().decode([String].self, from: data) else { return [] }
            return arr
        }
        set {
            mediaPathsJson = (try? JSONEncoder().encode(newValue)).flatMap { String(data: $0, encoding: .utf8) }
        }
    }

    /// "Safe" when available; customer name when on memo; "Sold" when sold. Use in lists and detail.
    var currentLocation: String {
        switch effectiveStatus {
        case .available:
            return "Safe"
        case .onMemo:
            return memo?.customer?.displayName ?? "On Memo"
        case .sold:
            return "Sold"
        }
    }
}


enum RFIDTagLifecycleStatus: String, Codable, CaseIterable {
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

@Model
final class RFIDTag {
    @Attribute(.unique) var epcCurrent: String
    var tidLastVerified: String?
    var status: RFIDTagLifecycleStatus
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
        status: RFIDTagLifecycleStatus = .unassigned,
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

enum StoneType: String, Codable, CaseIterable {
    case diamond = "Diamond"
    case emerald = "Emerald"
    case ruby = "Ruby"
    case sapphire = "Sapphire"
    case tanzanite = "Tanzanite"
}
