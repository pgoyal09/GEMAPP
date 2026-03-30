import Foundation
import SwiftData

@Model
final class Gemstone {

    // MARK: - Core Identity

    var sku: String
    var stoneType: StoneType
    var caratWeight: Double
    var shape: String
    var grouping: StoneGrouping
    var origin: String
    var createdAt: Date
    var status: GemstoneStatus

    // MARK: - Grading (all stones)

    var color: String
    var clarity: String
    var cut: String
    var treatment: String

    // MARK: - Diamond-Specific Grading

    var polish: String
    var symmetry: String
    var fluorescence: String

    // MARK: - Lot-Specific

    /// For diamond lots: free-text size range (e.g. "0.50-0.70 ct").
    var size: String?
    /// For non-diamond lots: quality grade (e.g. "AAA", "Commercial").
    var quality: String?

    // MARK: - Certification

    var hasCert: Bool
    var certLab: String
    var certNo: String

    // MARK: - Dimensions

    var length: Double?
    var width: Double?
    var height: Double?
    /// Second stone dimensions (pair grouping only).
    var length2: Double?
    var width2: Double?
    var height2: Double?

    // MARK: - Pricing

    var costPrice: Decimal
    var sellPrice: Decimal

    // MARK: - Lot Inventory

    /// Currently available carats for lot stones. Nil for non-lot stones.
    var remainingCarats: Double?
    /// Weighted-average cost per carat, recalculated when quantity is added.
    var averageCostPerCarat: Decimal?

    // MARK: - RFID

    /// Canonical RFID EPC for scanner lookup. Unique when present.
    var rfidEpc: String?
    /// RFID TID (manufacturer identity).
    var rfidTid: String?
    var rfidAssignedAt: Date?
    var rfidLastSeenAt: Date?

    // MARK: - Media

    var certificateImagePath: String?
    /// JSON-encoded array of file paths for media assets.
    var mediaPathsJson: String?

    // MARK: - Relationships

    @Relationship(deleteRule: .nullify)
    var memo: Memo?

    @Relationship(deleteRule: .cascade, inverse: \RFIDTag.assignedStone)
    var rfidTags: [RFIDTag] = []

    @Relationship(deleteRule: .cascade, inverse: \LotTransaction.gemstone)
    var lotTransactions: [LotTransaction] = []

    @Relationship(deleteRule: .cascade, inverse: \HistoryEvent.gemstone)
    var events: [HistoryEvent] = []

    // MARK: - Init

    init(
        sku: String,
        stoneType: StoneType,
        caratWeight: Double,
        shape: String = "",
        grouping: StoneGrouping = .single,
        origin: String = "",
        createdAt: Date = Date(),
        status: GemstoneStatus = .available,
        color: String = "",
        clarity: String = "",
        cut: String = "",
        treatment: String = "",
        polish: String = "",
        symmetry: String = "",
        fluorescence: String = "",
        size: String? = nil,
        quality: String? = nil,
        hasCert: Bool = false,
        certLab: String = "",
        certNo: String = "",
        length: Double? = nil,
        width: Double? = nil,
        height: Double? = nil,
        length2: Double? = nil,
        width2: Double? = nil,
        height2: Double? = nil,
        costPrice: Decimal = 0,
        sellPrice: Decimal = 0,
        remainingCarats: Double? = nil,
        averageCostPerCarat: Decimal? = nil,
        rfidEpc: String? = nil,
        rfidTid: String? = nil,
        rfidAssignedAt: Date? = nil,
        rfidLastSeenAt: Date? = nil,
        certificateImagePath: String? = nil,
        mediaPathsJson: String? = nil
    ) {
        self.sku = sku
        self.stoneType = stoneType
        self.caratWeight = caratWeight
        self.shape = shape
        self.grouping = grouping
        self.origin = origin
        self.createdAt = createdAt
        self.status = status
        self.color = color
        self.clarity = clarity
        self.cut = cut
        self.treatment = treatment
        self.polish = polish
        self.symmetry = symmetry
        self.fluorescence = fluorescence
        self.size = size
        self.quality = quality
        self.hasCert = hasCert
        self.certLab = certLab
        self.certNo = certNo
        self.length = length
        self.width = width
        self.height = height
        self.length2 = length2
        self.width2 = width2
        self.height2 = height2
        self.costPrice = costPrice
        self.sellPrice = sellPrice
        self.remainingCarats = remainingCarats
        self.averageCostPerCarat = averageCostPerCarat
        self.rfidEpc = rfidEpc
        self.rfidTid = rfidTid
        self.rfidAssignedAt = rfidAssignedAt
        self.rfidLastSeenAt = rfidLastSeenAt
        self.certificateImagePath = certificateImagePath
        self.mediaPathsJson = mediaPathsJson
    }

    // MARK: - Computed Properties

    var isLot: Bool { grouping == .lot }

    /// Effective remaining carats for lots. Falls back to caratWeight if not yet set.
    var effectiveRemainingCarats: Double {
        get { remainingCarats ?? caratWeight }
        set { remainingCarats = newValue }
    }

    /// Effective average cost per carat. Falls back to costPrice / caratWeight.
    var effectiveAverageCost: Decimal {
        averageCostPerCarat ?? (caratWeight > 0 ? costPrice / Decimal(caratWeight) : costPrice)
    }

    // MARK: - Review Queue Flags

    var missingDimensions: Bool {
        length == nil || width == nil || height == nil
    }

    var missingCertDetails: Bool {
        hasCert && (certLab.isEmpty || certNo.isEmpty)
    }

    var missingPricing: Bool {
        costPrice == 0 || sellPrice == 0
    }

    var missingDiamondGrading: Bool {
        stoneType == .diamond &&
        (color.isEmpty || clarity.isEmpty || cut.isEmpty ||
         polish.isEmpty || symmetry.isEmpty || fluorescence.isEmpty)
    }

    var needsReview: Bool {
        missingDimensions || missingCertDetails || missingPricing || missingDiamondGrading
    }

    // MARK: - Media

    var mediaPaths: [String] {
        get {
            guard let data = mediaPathsJson?.data(using: .utf8),
                  let arr = try? JSONDecoder().decode([String].self, from: data) else { return [] }
            return arr
        }
        set {
            mediaPathsJson = (try? JSONEncoder().encode(newValue))
                .flatMap { String(data: $0, encoding: .utf8) }
        }
    }

    // MARK: - Display

    /// Human-readable location: "Safe", customer name, or "Sold".
    var currentLocation: String {
        switch status {
        case .available: return "Safe"
        case .onMemo:    return memo?.customer?.displayName ?? "On Memo"
        case .sold:      return "Sold"
        }
    }

    /// Missing fields summary for review queue display.
    var missingFieldsSummary: [String] {
        var flags: [String] = []
        if missingDimensions { flags.append("Dimensions") }
        if missingCertDetails { flags.append("Certificate") }
        if missingPricing { flags.append("Pricing") }
        if missingDiamondGrading { flags.append("Diamond Grading") }
        return flags
    }
}
