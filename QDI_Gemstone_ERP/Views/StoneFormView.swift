import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import AppKit

enum StoneFormMode {
    case intake
    case review
    case edit
}

let stoneTypeOptions = StoneType.allCases.map(\.rawValue)
let shapeOptions = IntakeShape.allCases.map(\.rawValue)

struct StoneFormView: View {
    let mode: StoneFormMode
    var gemstone: Gemstone?
    var reviewQueue: [Gemstone] = []
    var currentReviewIndex: Int = 0
    var onSave: (() -> Void)?
    var onSaveAndNext: (() -> Void)?
    var onSaveAndClose: (() -> Void)?
    var onDismiss: (() -> Void)?
    var onDirtyStateChange: ((Bool) -> Void)?

    @Environment(\.modelContext) var modelContext
    @AppStorage("QuickIntake.lastStoneType") var lastStoneTypeRaw: String = StoneType.diamond.rawValue
    @AppStorage("QuickIntake.lastTreatment") var lastTreatment: String = ""

    @State var stoneTypeText: String = "Diamond"
    @State var shapeText: String = "Round"
    @State var grouping: IntakeGrouping = .single
    @State var caratsText: String = ""
    @State var treatment: String = ""
    @State var hasCert: Bool = false
    @State var skuText: String = ""
    @State var expandDeferred: Bool = true
    @State var showSuccess: Bool = false
    @FocusState var focusedField: StoneFormField?

    enum StoneFormField: Hashable {
        case stoneType, shape, carats, treatment, sku
        case color, clarity, cut, polish, symmetry, fluorescence
        case certLab, certNo, len, wid, hei, len2, wid2, hei2, cost, sell
        case size, quality
    }

    @State var color: String = ""
    @State var clarity: String = ""
    @State var cut: String = "EX"
    @State var polish: String = "EX"
    @State var symmetry: String = "EX"
    @State var fluorescence: String = "N"
    @State var certLab: String = ""
    @State var certNo: String = ""
    @State var lengthText: String = ""
    @State var widthText: String = ""
    @State var heightText: String = ""
    @State var length2Text: String = ""
    @State var width2Text: String = ""
    @State var height2Text: String = ""
    @State var costText: String = ""
    @State var sellText: String = ""
    @State var statusOverride: GemstoneStatus = .available
    @State var certificateImagePath: String = ""
    @State var mediaPathsLocal: [String] = []
    @State var showCertImagePicker = false
    @State var showMediaPicker = false
    @State var showLeaveWithoutSavingAlert = false
    @State var showSKUChangeConfirm = false
    @State var showSKUDuplicateError = false
    @State var pendingSKURevert: String?
    @State var pendingSaveAfterSKUConfirm = false
    @State var sizeText: String = ""
    @State var qualityText: String = ""
    @State var lastSavedStone: Gemstone?
    @State var isSavingInProgress = false

    // Rapaport fields
    @State var rapPriceText: String = ""
    @State var rapDiscountText: String = ""
    // Multi-currency fields
    @State var purchaseCurrency: String = "USD"
    @State var purchaseAmountText: String = ""
    @State var exchangeRateText: String = ""
    // GIA report
    @State var giaReportNumber: String = ""
    // Stone photo
    @State var stoneImageData: Data?

    var stoneType: StoneType { StoneType(rawValue: stoneTypeText) ?? .diamond }
    /// When true, diamond lot: only color, clarity, carats, size; cut/polish/symmetry/fluorescence/cert/dimensions/treatment disabled and cleared.
    var isDiamondLot: Bool { stoneType == .diamond && grouping == .lot }
    /// When true, non-diamond lot: shows Quality field.
    var isNonDiamondLot: Bool { stoneType != .diamond && grouping == .lot }
    var carats: Double? { Double(caratsText) }
    var costDecimal: Decimal? { Decimal(string: costText) }
    var sellDecimal: Decimal? { Decimal(string: sellText) }
    var lengthVal: Double? { Double(lengthText) }
    var widthVal: Double? { Double(widthText) }
    var heightVal: Double? { Double(heightText) }
    var length2Val: Double? { Double(length2Text) }
    var width2Val: Double? { Double(width2Text) }
    var height2Val: Double? { Double(height2Text) }

    var suggestedSKU: String {
        SKUGenerator.generateSKU(type: stoneType, shape: shapeText, grouping: grouping, modelContext: modelContext)
    }

    var canSave: Bool {
        guard carats != nil, carats! > 0 else { return false }
        if stoneType == .diamond {
            return !color.isEmpty && !clarity.isEmpty && !cut.isEmpty && !polish.isEmpty && !symmetry.isEmpty && !fluorescence.isEmpty
        }
        return true
    }

    var certFieldsDisabled: Bool { !hasCert || isDiamondLot }
    var hasNextInReview: Bool {
        mode == .review && currentReviewIndex + 1 < reviewQueue.count
    }

    func isMissing(_ check: Bool) -> Bool { mode == .review && check }
    func isMissingCost() -> Bool { mode == .review && (costDecimal == nil || costDecimal == 0) }
    func isMissingSell() -> Bool { mode == .review && (sellDecimal == nil || sellDecimal == 0) }
    func isMissingDimensions() -> Bool { mode == .review && (lengthVal == nil && widthVal == nil && heightVal == nil) }
    func isMissingCertDetails() -> Bool { mode == .review && hasCert && (certLab.isEmpty || certNo.isEmpty) }

    /// True when user has entered content worth saving. Autofilled SKU/type/shape alone do not count.
    var intakeFormHasContent: Bool {
        mode == .intake && !caratsText.isEmpty
    }

    var hasUnsavedChanges: Bool {
        guard mode == .edit, let g = gemstone else { return false }
        if stoneTypeText != g.stoneType.rawValue { return true }
        if shapeText != (g.shape ?? "Round") { return true }
        if grouping != groupingFromCode(g.grouping ?? "S") { return true }
        if caratsText != String(format: "%.2f", g.caratWeight) { return true }
        if treatment != (g.treatment ?? g.origin) { return true }
        if hasCert != (g.hasCert ?? false) { return true }
        if skuText != g.sku { return true }
        let colorVal = g.color == "-" ? "" : g.color
        if color != colorVal { return true }
        let clarityVal = g.clarity == "-" ? "" : g.clarity
        if clarity != clarityVal { return true }
        if certLab != (g.certLab ?? "") { return true }
        if certNo != (g.certNo ?? "") { return true }
        if lengthText != (g.length.map { String(format: "%.2f", $0) } ?? "") { return true }
        if widthText != (g.width.map { String(format: "%.2f", $0) } ?? "") { return true }
        if heightText != (g.height.map { String(format: "%.2f", $0) } ?? "") { return true }
        if length2Text != (g.length2.map { String(format: "%.2f", $0) } ?? "") { return true }
        if width2Text != (g.width2.map { String(format: "%.2f", $0) } ?? "") { return true }
        if height2Text != (g.height2.map { String(format: "%.2f", $0) } ?? "") { return true }
        if costText != (g.costPrice != 0 ? "\(g.costPrice)" : "") { return true }
        if sellText != (g.sellPrice != 0 ? "\(g.sellPrice)" : "") { return true }
        if certificateImagePath != (g.certificateImagePath ?? "") { return true }
        if mediaPathsLocal != g.mediaPaths { return true }
        return false
    }

    var body: some View {
        Group {
            if mode == .edit {
                editFormBody
            } else {
                intakeReviewBody
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background)
        .onAppear { loadFromGemstoneOrDefaults(); onDirtyStateChange?(intakeFormHasContent || hasUnsavedChanges) }
        .onChange(of: gemstone?.id) { _, _ in loadFromGemstoneOrDefaults() }
        .onChange(of: stoneTypeText) { _, _ in refreshSKUIfNeeded() }
        .onChange(of: caratsText) { _, _ in onDirtyStateChange?(intakeFormHasContent || hasUnsavedChanges) }
        .onChange(of: skuText) { _, _ in onDirtyStateChange?(intakeFormHasContent || hasUnsavedChanges) }
        .onChange(of: shapeText) { _, _ in refreshSKUIfNeeded() }
        .onChange(of: grouping) { _, newGrouping in
            refreshSKUIfNeeded()
            if stoneType == .diamond && newGrouping == .lot {
                cut = "EX"
                polish = "EX"
                symmetry = "EX"
                fluorescence = "N"
                hasCert = false
                certLab = ""
                certNo = ""
                lengthText = ""
                widthText = ""
                heightText = ""
                length2Text = ""
                width2Text = ""
                height2Text = ""
                treatment = ""
            }
            if newGrouping != .lot {
                qualityText = ""
            }
        }
        .alert("Leave without saving?", isPresented: $showLeaveWithoutSavingAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Discard edits and leave", role: .destructive) {
                onDismiss?()
            }
        } message: {
            Text("Your changes will not be saved.")
        }
        .alert("Are you sure you want to change the SKU?", isPresented: $showSKUChangeConfirm) {
            Button("Cancel", role: .cancel) {
                if let revert = pendingSKURevert { skuText = revert }
                pendingSKURevert = nil
                pendingSaveAfterSKUConfirm = false
            }
            Button("Change SKU", role: .destructive) {
                commitSKUChange()
            }
        } message: {
            Text("Manual SKU changes require confirmation.")
        }
        .alert("This SKU already exists. Please try another.", isPresented: $showSKUDuplicateError) {
            Button("OK", role: .cancel) {
                if let revert = pendingSKURevert { skuText = revert }
                pendingSKURevert = nil
            }
        }
        .overlay {
            if showSuccess {
                Text("Saved")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, AppSpacing.l)
                    .padding(.vertical, AppSpacing.m)
                    .background(AppColors.success, in: RoundedRectangle(cornerRadius: AppCornerRadius.m, style: .continuous))
            }
        }
        .fileImporter(
            isPresented: $showCertImagePicker,
            allowedContentTypes: [.image, .pdf],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            _ = url.startAccessingSecurityScopedResource()
            certificateImagePath = url.path
        }
        .fileImporter(
            isPresented: $showMediaPicker,
            allowedContentTypes: [.image, .movie, .video, .pdf],
            allowsMultipleSelection: true
        ) { result in
            guard case .success(let urls) = result else { return }
            for url in urls {
                _ = url.startAccessingSecurityScopedResource()
                let path = url.path
                if !mediaPathsLocal.contains(path) {
                    mediaPathsLocal.append(path)
                }
            }
        }
    }

    @ViewBuilder
    var intakeReviewBody: some View {
        if mode == .review {
            reviewFormBody
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.m) {
                    intakeHeader
                    row1
                    row2
                    HStack(spacing: AppSpacing.m) {
                        skuField
                        Spacer(minLength: 0)
                    }
                    if stoneType == .diamond {
                        diamondSection
                    }
                    deferredSection
                    HStack {
                        Spacer(minLength: 0)
                        saveButtons
                    }
                    .padding(.top, AppSpacing.s)
                }
                .padding(AppSpacing.m)
            }
        }
    }
}
