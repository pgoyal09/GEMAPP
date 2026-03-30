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

    /// Display currency for this stone (defaults to USD).
    var currencyType: CurrencyType
    /// Exchange rate to USD (e.g. 83.5 for INR). 1.0 when currency is USD.
    var exchangeRate: Decimal

    // MARK: - Lot Inventory

    /// Currently available carats for lot stones. Nil for non-lot stones.
    // FIXME: Ideally Decimal for exact precision, but SwiftData #Predicate does not
    // support Decimal comparisons. Double with 4-decimal rounding is used as a
    // workaround. Revisit when SwiftData adds Decimal predicate support.
    /// All writes should go through `effectiveRemainingCarats` to ensure rounding.
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

    // MARK: - RapNet Shared Fields

    /// Listing status: "G" (Guaranteed), "M" (On Memo), "STPS", "NA"
    var availability: String?
    /// Physical location country (NOT origin).
    var stoneCountry: String?
    /// Physical location city.
    var stoneCity: String?
    /// Physical location state.
    var stoneState: String?
    /// HTTPS video link.
    var videoUrl: String?

    // MARK: - Diamond-Only RapNet Fields

    /// $/ct asking price on RapNet.
    var rapNetPrice: Decimal?
    /// % below Rap list (e.g., -0.30 = 30% below).
    var rapNetDiscountPct: Double?
    /// Cash-on-delivery $/ct.
    var cashPrice: Decimal?
    /// Cash discount as % of Rap.
    var cashDiscountPct: Double?
    /// Depth percentage (e.g., 62.4).
    var depthPct: Double?
    /// Table percentage (e.g., 60).
    var tablePct: Double?
    /// Fluorescence intensity: VS/S/M/F/SL/VSL/N.
    var fluorescenceIntensity: String?
    /// Fluorescence color: B/W/Y/O/R/G/N.
    var fluorescenceColor: String?
    /// Fancy color: BK/B/BN/CH/CM/CG/GY/G/O/P/PL/R/V/Y/W/X.
    var fancyColor: String?
    /// Fancy color intensity: F/VL/L/FCL/FC/FCD/I/FV/D.
    var fancyColorIntensity: String?
    /// Free text fancy color overtone.
    var fancyColorOvertone: String?
    /// Eye clean assessment: "Yes"/"Borderline"/"E1"/"E2".
    var eyeClean: String?

    // MARK: - Gemstone-Only RapNet Fields

    /// Vendor primary color assessment (mandatory for RapNet gem upload).
    var primaryColorVendor: String?
    /// Vendor color intensity assessment.
    var colorIntensityVendor: String?
    /// Vendor color modifier assessment.
    var colorModifiersVendor: String?
    /// Free text color description.
    var colorDescription: String?
    /// Lab primary color assessment.
    var primaryColorLab: String?
    /// Lab color intensity.
    var colorIntensityLab: String?
    /// Lab color modifiers.
    var colorModifiersLab: String?
    /// Second treatment type.
    var treatmentType2: String?
    /// Third treatment type.
    var treatmentType3: String?
    /// Free text treatment notes.
    var treatmentNotes: String?
    /// Number of stones (for gem parcels).
    var numberOfStones: Int?

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

    @Relationship(deleteRule: .nullify, inverse: \HistoryEvent.gemstone)
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
        currencyType: CurrencyType = .usd,
        exchangeRate: Decimal = 1,
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
        self.currencyType = currencyType
        self.exchangeRate = exchangeRate
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
    /// Rounded to 4 decimal places to prevent floating-point drift.
    var effectiveRemainingCarats: Double {
        get {
            let result = remainingCarats ?? caratWeight
            return (result * 10000).rounded() / 10000
        }
        set { remainingCarats = (max(0, newValue) * 10000).rounded() / 10000 }
    }

    /// Effective average cost per carat. Falls back to costPrice / caratWeight.
    var effectiveAverageCost: Decimal {
        averageCostPerCarat ?? (caratWeight > 0 ? costPrice / Decimal(caratWeight) : costPrice)
    }

    // MARK: - Pricing Engine

    /// RapNet calculated price per carat: rapNetPrice * (1 - rapNetDiscountPct/100).
    var rapNetCalculatedPrice: Decimal? {
        guard let rap = rapNetPrice, let disc = rapNetDiscountPct else { return nil }
        return rap * (1 - Decimal(disc) / 100)
    }

    /// Effective per-carat price: sellPrice if set, otherwise rapNetCalculatedPrice.
    var perCaratPrice: Decimal? {
        if sellPrice > 0 { return sellPrice }
        return rapNetCalculatedPrice
    }

    /// Sell price converted to display currency using the exchange rate.
    var sellPriceInDisplayCurrency: Decimal {
        sellPrice * exchangeRate
    }

    /// Cost price converted to display currency using the exchange rate.
    var costPriceInDisplayCurrency: Decimal {
        costPrice * exchangeRate
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
        case .available:    return "Safe"
        case .onMemo:       return memo?.customer?.displayName ?? "On Memo"
        case .sold:         return "Sold"
        case .atLab:        return "At Lab"
        case .reserved:     return "Reserved"
        case .inTransit:    return "In Transit"
        case .consignment:  return "Consignment"
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
