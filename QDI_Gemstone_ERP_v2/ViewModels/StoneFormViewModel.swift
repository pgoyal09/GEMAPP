import Foundation
import SwiftData

/// Form mode for the stone intake/edit/review flow.
enum StoneFormMode {
    case intake
    case edit(Gemstone)
    case review(Gemstone)

    var existingStone: Gemstone? {
        switch self {
        case .intake: return nil
        case .edit(let s), .review(let s): return s
        }
    }

    var isEditing: Bool {
        if case .edit = self { return true }
        return false
    }
}

@MainActor
@Observable
final class StoneFormViewModel {

    // MARK: - Mode

    let mode: StoneFormMode

    // MARK: - Core Fields

    var sku: String = ""
    var stoneTypeText: String = StoneType.diamond.rawValue
    var shapeText: String = ""
    var grouping: StoneGrouping = .single
    var origin: String = ""

    // MARK: - Grading

    var color: String = ""
    var clarity: String = ""
    var cut: String = ""
    var treatment: String = ""

    // MARK: - Diamond-specific

    var polish: String = ""
    var symmetry: String = ""
    var fluorescence: String = ""

    // MARK: - Lot-specific

    var size: String = ""
    var quality: String = ""

    // MARK: - Certification

    var hasCert: Bool = false
    var certLab: String = ""
    var certNo: String = ""

    // MARK: - Measurements

    var caratText: String = ""
    var lengthText: String = ""
    var widthText: String = ""
    var heightText: String = ""
    var length2Text: String = ""
    var width2Text: String = ""
    var height2Text: String = ""

    // MARK: - Pricing

    var costPriceText: String = ""
    var sellPriceText: String = ""

    // MARK: - Media

    var certificateImagePath: String? = nil
    var mediaPaths: [String] = []

    // MARK: - UI State

    var showSKUConfirmation: Bool = false
    var pendingSKU: String = ""
    var toastMessage: String? = nil
    var toastIsError: Bool = false

    // MARK: - Init

    init(mode: StoneFormMode) {
        self.mode = mode
        if let stone = mode.existingStone {
            loadFrom(stone)
        }
    }

    // MARK: - Computed

    var stoneType: StoneType {
        StoneType(rawValue: stoneTypeText) ?? .diamond
    }

    var isDiamond: Bool { stoneType == .diamond }
    var isLot: Bool { grouping == .lot }
    var isPair: Bool { grouping == .pair }

    var caratWeight: Double { Double(caratText) ?? 0 }
    var costPrice: Decimal { Decimal(string: costPriceText) ?? 0 }
    var sellPrice: Decimal { Decimal(string: sellPriceText) ?? 0 }

    var canSave: Bool { caratWeight > 0 && !sku.isEmpty }

    var hasUnsavedChanges: Bool {
        guard let stone = mode.existingStone else { return true }
        return sku != stone.sku ||
            stoneTypeText != stone.stoneType.rawValue ||
            shapeText != stone.shape ||
            grouping != stone.grouping ||
            caratWeight != stone.caratWeight ||
            color != stone.color ||
            clarity != stone.clarity ||
            cut != stone.cut ||
            costPrice != stone.costPrice ||
            sellPrice != stone.sellPrice
    }

    // MARK: - SKU Management

    func refreshSKU(modelContext: ModelContext) {
        guard !mode.isEditing else { return }
        let type = StoneType(rawValue: stoneTypeText) ?? .diamond
        let newSKU = SKUGenerator.generate(
            type: type,
            shape: shapeText,
            grouping: grouping,
            modelContext: modelContext
        )
        if newSKU != sku {
            sku = newSKU
        }
    }

    func validateSKUChange(newSKU: String, modelContext: ModelContext) {
        guard newSKU != sku else { return }
        if SKUGenerator.exists(sku: newSKU, modelContext: modelContext) {
            pendingSKU = newSKU
            showSKUConfirmation = true
        } else {
            sku = newSKU
        }
    }

    func commitSKUChange() {
        sku = pendingSKU
        pendingSKU = ""
        showSKUConfirmation = false
    }

    // MARK: - Save

    func save(modelContext: ModelContext) throws {
        guard caratWeight > 0 else {
            toastMessage = "Carat weight must be greater than zero"
            toastIsError = true
            return
        }

        if let stone = mode.existingStone {
            applyTo(stone)
            try modelContext.save()
            toastMessage = "Stone updated"
            toastIsError = false
        } else {
            let stone = Gemstone(sku: sku, stoneType: stoneType, caratWeight: caratWeight)
            applyTo(stone)
            modelContext.insert(stone)
            HistoryLogger.logQuietly(stone: stone, type: .dateAdded,
                                      message: "Added to inventory", modelContext: modelContext)
            try modelContext.save()
            toastMessage = "Stone saved"
            toastIsError = false
        }
    }

    /// Save then reset form for rapid sequential intake.
    func saveAndContinue(modelContext: ModelContext) throws {
        try save(modelContext: modelContext)
        // Preserve type/shape/grouping for next stone, clear everything else
        let prevType = stoneTypeText
        let prevShape = shapeText
        let prevGrouping = grouping
        resetFields()
        stoneTypeText = prevType
        shapeText = prevShape
        grouping = prevGrouping
        refreshSKU(modelContext: modelContext)
    }

    /// Duplicate: pre-fill from saved stone but clear carat/price.
    func prepareForDuplicate() {
        caratText = ""
        costPriceText = ""
        sellPriceText = ""
        sku = ""
    }

    // MARK: - Private

    private func loadFrom(_ stone: Gemstone) {
        sku = stone.sku
        stoneTypeText = stone.stoneType.rawValue
        shapeText = stone.shape
        grouping = stone.grouping
        origin = stone.origin
        color = stone.color
        clarity = stone.clarity
        cut = stone.cut
        treatment = stone.treatment
        polish = stone.polish
        symmetry = stone.symmetry
        fluorescence = stone.fluorescence
        size = stone.size ?? ""
        quality = stone.quality ?? ""
        hasCert = stone.hasCert
        certLab = stone.certLab
        certNo = stone.certNo
        caratText = "\(stone.caratWeight)"
        lengthText = stone.length.map { "\($0)" } ?? ""
        widthText = stone.width.map { "\($0)" } ?? ""
        heightText = stone.height.map { "\($0)" } ?? ""
        length2Text = stone.length2.map { "\($0)" } ?? ""
        width2Text = stone.width2.map { "\($0)" } ?? ""
        height2Text = stone.height2.map { "\($0)" } ?? ""
        costPriceText = "\(stone.costPrice)"
        sellPriceText = "\(stone.sellPrice)"
        certificateImagePath = stone.certificateImagePath
        mediaPaths = stone.mediaPaths
    }

    private func applyTo(_ stone: Gemstone) {
        stone.sku = sku
        stone.stoneType = stoneType
        stone.shape = shapeText
        stone.grouping = grouping
        stone.origin = origin
        stone.caratWeight = caratWeight
        stone.color = color
        stone.clarity = clarity
        stone.cut = cut
        stone.treatment = treatment

        // Diamond-specific
        if isDiamond {
            stone.polish = polish
            stone.symmetry = symmetry
            stone.fluorescence = fluorescence
        } else {
            stone.polish = ""
            stone.symmetry = ""
            stone.fluorescence = ""
        }

        // Lot-specific
        stone.size = isLot ? size : nil
        stone.quality = isLot ? quality : nil

        // Certification
        stone.hasCert = hasCert
        stone.certLab = hasCert ? certLab : ""
        stone.certNo = hasCert ? certNo : ""

        // Dimensions
        stone.length = Double(lengthText)
        stone.width = Double(widthText)
        stone.height = Double(heightText)
        stone.length2 = isPair ? Double(length2Text) : nil
        stone.width2 = isPair ? Double(width2Text) : nil
        stone.height2 = isPair ? Double(height2Text) : nil

        // Pricing
        stone.costPrice = costPrice
        stone.sellPrice = sellPrice

        // Lot inventory
        if isLot && stone.remainingCarats == nil {
            stone.remainingCarats = caratWeight
        }

        // Media
        stone.certificateImagePath = certificateImagePath
        stone.mediaPaths = mediaPaths
    }

    private func resetFields() {
        sku = ""
        origin = ""
        color = ""
        clarity = ""
        cut = ""
        treatment = ""
        polish = ""
        symmetry = ""
        fluorescence = ""
        size = ""
        quality = ""
        hasCert = false
        certLab = ""
        certNo = ""
        caratText = ""
        lengthText = ""
        widthText = ""
        heightText = ""
        length2Text = ""
        width2Text = ""
        height2Text = ""
        costPriceText = ""
        sellPriceText = ""
        certificateImagePath = nil
        mediaPaths = []
        toastMessage = nil
    }
}
