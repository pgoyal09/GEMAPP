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
    /// For diamond lots: free-text size (e.g. "0.50-0.70 ct").
    var size: String?
    /// For non-diamond lots: quality grade (e.g. "AAA", "Commercial").
    var quality: String?

    // MARK: - Lot Inventory Fields

    /// For lot stones: currently available carats (decremented when sent on memo/sold).
    /// Nil for non-lot stones. Defaults to caratWeight on first use via effectiveRemainingCarats.
    var remainingCarats: Double?
    /// Weighted-average cost per carat, recalculated each time quantity is added.
    var averageCostPerCarat: Decimal?

    @Relationship(deleteRule: .nullify, inverse: \LotTransaction.gemstone)
    var lotTransactions: [LotTransaction] = []
    
    // MARK: - Rapaport Price Fields
    /// Rapaport list price per carat at time of listing.
    var rapPrice: Decimal?
    /// Discount from Rapaport list (e.g. -15 means 15% below Rap).
    var rapDiscount: Double?

    // MARK: - Per-Stone P&L Fields
    /// Actual price the stone was sold for (set when status changes to .sold).
    var soldPrice: Decimal?
    /// Date the stone was sold.
    var soldDate: Date?

    // MARK: - Multi-Currency Support
    /// Currency code for original purchase (e.g. "INR", "USD").
    var purchaseCurrency: String?
    /// Original purchase amount in purchaseCurrency.
    var purchaseAmount: Decimal?
    /// Exchange rate to USD at time of purchase.
    var exchangeRate: Double?

    // MARK: - GIA Report
    /// GIA report number for certificate lookup.
    var giaReportNumber: String?

    // MARK: - Stone Photography
    /// Binary image data for primary stone photo.
    var imageData: Data?

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
        fluorescence: String? = nil,
        size: String? = nil,
        quality: String? = nil
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
        self.size = size
        self.quality = quality
    }
    
    /// True if this stone is a lot (grouping == "L").
    var isLot: Bool { grouping == "L" }

    /// Effective remaining carats for lots. Falls back to caratWeight if not yet set.
    var effectiveRemainingCarats: Double {
        get { remainingCarats ?? caratWeight }
        set { remainingCarats = newValue }
    }

    /// Effective average cost per carat. Falls back to costPrice (total, not per-carat) if not set.
    /// Note: for lots costPrice is total cost for the initial lot; averageCostPerCarat is derived.
    var effectiveAverageCost: Decimal {
        averageCostPerCarat ?? (caratWeight > 0 ? costPrice / Decimal(caratWeight) : costPrice)
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

    // MARK: - Rapaport Computed Properties

    /// Calculated Rapaport price per carat after discount.
    var rapPricePerCarat: Decimal? {
        guard let rap = rapPrice, let discount = rapDiscount else { return nil }
        return rap * (1 - Decimal(discount / 100))
    }

    /// Calculated total Rapaport price.
    var rapTotalPrice: Decimal? {
        guard let ppc = rapPricePerCarat else { return nil }
        return ppc * Decimal(caratWeight)
    }

    // MARK: - Per-Stone P&L Computed Properties

    /// Profit margin (sold price - cost price).
    var margin: Decimal? {
        guard let sold = soldPrice else { return nil }
        return sold - costPrice
    }

    /// Return on investment as percentage ((sold - cost) / cost * 100).
    var roi: Double? {
        guard let sold = soldPrice, costPrice > 0 else { return nil }
        let m = sold - costPrice
        return NSDecimalNumber(decimal: m / costPrice * 100).doubleValue
    }

    /// Days held from creation to sold date (or to now if not yet sold).
    var daysHeld: Int {
        let endDate = soldDate ?? Date()
        return Calendar.current.dateComponents([.day], from: createdAt, to: endDate).day ?? 0
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
