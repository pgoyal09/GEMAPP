import SwiftUI
import SwiftData

enum StoneFormMode {
    case intake
    case review
    case edit
}

private let stoneTypeOptions = StoneType.allCases.map(\.rawValue)
private let shapeOptions = IntakeShape.allCases.map(\.rawValue)

struct StoneFormView: View {
    let mode: StoneFormMode
    var gemstone: Gemstone?
    var reviewQueue: [Gemstone] = []
    var currentReviewIndex: Int = 0
    var onSave: (() -> Void)?
    var onSaveAndNext: (() -> Void)?
    var onSaveAndClose: (() -> Void)?
    var onDismiss: (() -> Void)?

    @Environment(\.modelContext) private var modelContext
    @AppStorage("QuickIntake.lastStoneType") private var lastStoneTypeRaw: String = StoneType.diamond.rawValue
    @AppStorage("QuickIntake.lastTreatment") private var lastTreatment: String = "None"

    @State private var stoneTypeText: String = "Diamond"
    @State private var shapeText: String = "Round"
    @State private var grouping: IntakeGrouping = .single
    @State private var caratsText: String = ""
    @State private var treatment: String = "None"
    @State private var hasCert: Bool = false
    @State private var skuText: String = ""
    @State private var expandDeferred: Bool = true
    @State private var showSuccess: Bool = false
    @FocusState private var focusedField: StoneFormField?

    enum StoneFormField: Hashable {
        case stoneType, shape, carats, treatment, sku
        case color, clarity, cut, polish, symmetry, fluorescence
        case certLab, certNo, len, wid, hei, cost, sell
    }

    @State private var color: String = ""
    @State private var clarity: String = ""
    @State private var cut: String = "EX"
    @State private var polish: String = "EX"
    @State private var symmetry: String = "EX"
    @State private var fluorescence: String = "N"
    @State private var certLab: String = ""
    @State private var certNo: String = ""
    @State private var lengthText: String = ""
    @State private var widthText: String = ""
    @State private var heightText: String = ""
    @State private var costText: String = ""
    @State private var sellText: String = ""
    @State private var statusOverride: GemstoneStatus = .available

    private var stoneType: StoneType { StoneType(rawValue: stoneTypeText) ?? .diamond }
    private var carats: Double? { Double(caratsText) }
    private var costDecimal: Decimal? { Decimal(string: costText) }
    private var sellDecimal: Decimal? { Decimal(string: sellText) }
    private var lengthVal: Double? { Double(lengthText) }
    private var widthVal: Double? { Double(widthText) }
    private var heightVal: Double? { Double(heightText) }

    private var suggestedSKU: String {
        SKUGenerator.generateSKU(type: stoneType, shape: shapeText, grouping: grouping, modelContext: modelContext)
    }

    private var canSave: Bool {
        guard carats != nil, carats! > 0 else { return false }
        if stoneType == .diamond {
            return !color.isEmpty && !clarity.isEmpty && !cut.isEmpty && !polish.isEmpty && !symmetry.isEmpty && !fluorescence.isEmpty
        }
        return true
    }

    private var certFieldsDisabled: Bool { !hasCert }
    private var hasNextInReview: Bool {
        mode == .review && currentReviewIndex + 1 < reviewQueue.count
    }

    private func isMissing(_ check: Bool) -> Bool { mode == .review && check }
    private func isMissingCost() -> Bool { mode == .review && (costDecimal == nil || costDecimal == 0) }
    private func isMissingSell() -> Bool { mode == .review && (sellDecimal == nil || sellDecimal == 0) }
    private func isMissingDimensions() -> Bool { mode == .review && (lengthVal == nil && widthVal == nil && heightVal == nil) }
    private func isMissingCertDetails() -> Bool { mode == .review && hasCert && (certLab.isEmpty || certNo.isEmpty) }

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
        .onAppear { loadFromGemstoneOrDefaults() }
        .onChange(of: gemstone?.id) { _, _ in loadFromGemstoneOrDefaults() }
        .onChange(of: stoneTypeText) { _, _ in refreshSKUIfNeeded() }
        .onChange(of: shapeText) { _, _ in refreshSKUIfNeeded() }
        .onChange(of: grouping) { _, _ in refreshSKUIfNeeded() }
        .overlay {
            if showSuccess {
                Text("Saved")
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, AppSpacing.l)
                    .padding(.vertical, AppSpacing.m)
                    .background(Color.green)
                    .cornerRadius(AppCornerRadius.m)
            }
        }
    }

    private var intakeReviewBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.l) {
                if mode == .intake {
                    intakeHeader
                }
                row1
                row2
                row3
                if stoneType == .diamond {
                    diamondSection
                }
                deferredSection
            }
            .padding(AppSpacing.xl)
        }
    }

    private var editFormBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                editHeaderSection
                HStack(alignment: .top, spacing: AppSpacing.l) {
                    editLeftColumn
                    editRightColumn
                }
                if stoneType == .diamond {
                    editDiamondSection
                }
            }
            .padding(AppSpacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var editHeaderSection: some View {
        HStack(alignment: .center, spacing: AppSpacing.m) {
            VStack(alignment: .leading, spacing: 4) {
                Text("SKU")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("SKU", text: $skuText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 140)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Stone Type")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                AutocompleteFieldView(label: "", text: $stoneTypeText, options: stoneTypeOptions, placeholder: "Diamond", showLabel: false)
            }
            .frame(width: 130)
            VStack(alignment: .leading, spacing: 4) {
                Text("Status")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("", selection: $statusOverride) {
                    ForEach(GemstoneStatus.allCases, id: \.self) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 110)
                .labelsHidden()
            }
            Spacer()
            if gemstone != nil {
                Button("Regenerate SKU") {
                    skuText = suggestedSKU
                }
                .buttonStyle(.bordered)
            }
            HStack(spacing: AppSpacing.s) {
                if let onDismiss {
                    Button("Cancel") { onDismiss() }
                        .keyboardShortcut(.cancelAction)
                }
                Button("Save") {
                    if saveCurrent() {
                        showSuccessFeedback()
                        onSave?()
                    }
                }
                .disabled(!canSave)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(AppSpacing.m)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(AppCornerRadius.m)
    }

    private var editLeftColumn: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Text("Core identity")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
            editField("Shape") {
                AutocompleteFieldView(label: "", text: $shapeText, options: shapeOptions, placeholder: "Round")
            }
            editField("Single / Pair / Lot") {
                Picker("", selection: $grouping) {
                    ForEach(IntakeGrouping.allCases) { g in
                        Text(g.rawValue).tag(g)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            editField("Carat", binding: $caratsText)
            editField("Treatment", binding: $treatment)
            editField("Certified") {
                Picker("", selection: $hasCert) {
                    Text("No").tag(false)
                    Text("Yes").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.m)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(AppCornerRadius.m)
    }

    private var editRightColumn: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Text("Detail / Commercial")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
            editField("Cert Lab") {
                TextField("", text: $certLab)
                    .textFieldStyle(.roundedBorder)
                    .disabled(certFieldsDisabled)
            }
            .opacity(certFieldsDisabled ? 0.6 : 1)
            editField("Cert No") {
                TextField("", text: $certNo)
                    .textFieldStyle(.roundedBorder)
                    .disabled(certFieldsDisabled)
            }
            .opacity(certFieldsDisabled ? 0.6 : 1)
            HStack(spacing: AppSpacing.s) {
                editField("L", binding: $lengthText)
                editField("W", binding: $widthText)
                editField("H", binding: $heightText)
            }
            editField("Cost", binding: $costText)
            editField("Sell Price", binding: $sellText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.m)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(AppCornerRadius.m)
    }

    private var editDiamondSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Text("Diamond grading")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: AppSpacing.s) {
                editField("Color", binding: $color)
                editField("Clarity", binding: $clarity)
                editField("Cut", binding: $cut)
                editField("Polish", binding: $polish)
                editField("Symmetry", binding: $symmetry)
                editField("Fluorescence", binding: $fluorescence)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.m)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(AppCornerRadius.m)
    }

    private func editField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func editField(_ label: String, binding: Binding<String>) -> some View {
        editField(label) {
            TextField("", text: binding)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var intakeHeader: some View {
        HStack {
            Text("Quick Intake")
                .font(.headline)
            Spacer()
        }
    }

    private var row1: some View {
        HStack(spacing: AppSpacing.m) {
            AutocompleteFieldView(label: "Stone Type", text: $stoneTypeText, options: stoneTypeOptions, placeholder: "Diamond")
            AutocompleteFieldView(label: "Shape", text: $shapeText, options: shapeOptions, placeholder: "Round")
            groupingPicker
        }
    }

    private var groupingPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Single / Pair / Lot")
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker("", selection: $grouping) {
                ForEach(IntakeGrouping.allCases) { g in
                    Text(g.rawValue).tag(g)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    private var row2: some View {
        HStack(spacing: AppSpacing.m) {
            caratsField
            treatmentField
            certToggle
        }
    }

    private var caratsField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Carats")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("0.00", text: $caratsText)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .carats)
        }
    }

    private var treatmentField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Treatment")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("None", text: $treatment)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .treatment)
        }
    }

    private var certToggle: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Cert")
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker("", selection: $hasCert) {
                Text("No").tag(false)
                Text("Yes").tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    private var row3: some View {
        HStack(spacing: AppSpacing.m) {
            skuField
            saveButtons
        }
    }

    private var skuField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("SKU")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("Auto", text: $skuText)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .sku)
        }
    }

    @ViewBuilder
    private var saveButtons: some View {
        HStack(spacing: AppSpacing.m) {
            switch mode {
            case .intake:
                Button("Save") { performSave(stay: true) }
                    .disabled(!canSave)
                    .keyboardShortcut(.defaultAction)
                Button("Save + Next") { performSave(stay: false) }
                    .disabled(!canSave)
                Button("Save + Dup Prev") { performSaveDuplicate() }
                    .disabled(!canSave)
            case .review:
                Button("Save") {
                    saveCurrent()
                    showSuccessFeedback()
                }
                .disabled(!canSave)
                Button("Save + Next") {
                    saveCurrent()
                    showSuccessFeedback()
                    onSaveAndNext?()
                }
                .disabled(!canSave || !hasNextInReview)
                if let onDismiss {
                    Button("Done") { onDismiss() }
                }
            case .edit:
                Button("Save") {
                    _ = saveCurrent()
                    showSuccessFeedback()
                    onSave?()
                }
                .disabled(!canSave)
                .keyboardShortcut(.defaultAction)
                if let onDismiss {
                    Button("Done") { onDismiss() }
                }
            }
        }
    }

    private var diamondSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            Text("Diamond grading")
                .font(.headline)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: AppSpacing.m) {
                formField("Color", $color, .color, missing: isMissing(stoneType == .diamond && color.isEmpty))
                formField("Clarity", $clarity, .clarity, missing: isMissing(stoneType == .diamond && clarity.isEmpty))
                formField("Cut", $cut, .cut, missing: false)
                formField("Polish", $polish, .polish, missing: false)
                formField("Symmetry", $symmetry, .symmetry, missing: false)
                formField("Fluorescence", $fluorescence, .fluorescence, missing: false)
            }
        }
        .padding(AppSpacing.l)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(AppCornerRadius.l)
    }

    private func formField(_ label: String, _ binding: Binding<String>, _ field: StoneFormField, missing: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(missing ? Color.orange : Color.secondary)
            TextField("", text: binding)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: field)
        }
    }

    private var deferredSection: some View {
        DisclosureGroup("Deferred fields (Cert Lab, Dimensions, Cost, Sell)", isExpanded: $expandDeferred) {
            HStack(spacing: AppSpacing.m) {
                certLabField
                certNoField
                dimensionField("L", $lengthText, .len)
                dimensionField("W", $widthText, .wid)
                dimensionField("H", $heightText, .hei)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Cost")
                        .font(.caption)
                        .foregroundStyle(isMissingCost() ? Color.orange : Color.secondary)
                    TextField("", text: $costText)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .cost)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sell Price")
                        .font(.caption)
                        .foregroundStyle(isMissingSell() ? Color.orange : Color.secondary)
                    TextField("", text: $sellText)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .sell)
                }
            }
        }
    }

    private var certLabField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Cert Lab")
                .font(.caption)
                .foregroundStyle(certFieldsDisabled ? Color.primary.opacity(0.4) : (isMissingCertDetails() ? Color.orange : Color.secondary))
            TextField("", text: $certLab)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .certLab)
                .disabled(certFieldsDisabled)
        }
    }

    private var certNoField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Cert No")
                .font(.caption)
                .foregroundStyle(certFieldsDisabled ? Color.primary.opacity(0.4) : (isMissingCertDetails() ? Color.orange : Color.secondary))
            TextField("", text: $certNo)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .certNo)
                .disabled(certFieldsDisabled)
        }
    }

    private func dimensionField(_ label: String, _ binding: Binding<String>, _ field: StoneFormField) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("", text: binding)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: field)
        }
    }

    private func loadFromGemstoneOrDefaults() {
        if let g = gemstone {
            statusOverride = g.effectiveStatus
            stoneTypeText = g.stoneType.rawValue
            shapeText = g.shape ?? "Round"
            grouping = groupingFromCode(g.grouping ?? "S")
            caratsText = String(format: "%.2f", g.caratWeight)
            treatment = g.treatment ?? g.origin
            hasCert = g.hasCert ?? false
            skuText = g.sku
            color = g.color == "-" ? "" : g.color
            clarity = g.clarity == "-" ? "" : g.clarity
            cut = g.cut == "-" ? "EX" : g.cut
            polish = g.polish ?? "EX"
            symmetry = g.symmetry ?? "EX"
            fluorescence = g.fluorescence ?? "N"
            certLab = g.certLab ?? ""
            certNo = g.certNo ?? ""
            lengthText = g.length.map { String(format: "%.2f", $0) } ?? ""
            widthText = g.width.map { String(format: "%.2f", $0) } ?? ""
            heightText = g.height.map { String(format: "%.2f", $0) } ?? ""
            costText = g.costPrice != 0 ? "\(g.costPrice)" : ""
            sellText = g.sellPrice != 0 ? "\(g.sellPrice)" : ""
        } else {
            stoneTypeText = StoneType(rawValue: lastStoneTypeRaw)?.rawValue ?? "Diamond"
            shapeText = "Round"
            grouping = .single
            caratsText = ""
            treatment = lastTreatment
            hasCert = false
            skuText = suggestedSKU
            color = ""
            clarity = ""
            cut = "EX"
            polish = "EX"
            symmetry = "EX"
            fluorescence = "N"
            certLab = ""
            certNo = ""
            lengthText = ""
            widthText = ""
            heightText = ""
            costText = ""
            sellText = ""
        }
    }

    private func refreshSKUIfNeeded() {
        guard mode == .intake else { return }
        // Always refresh SKU from current type/shape/group when they change.
        // Previous logic only refreshed when prefix matched, causing stale DI- prefix on Ruby/Emerald.
        let expected = SKUGenerator.expectedPrefix(type: stoneType, shapeString: shapeText, grouping: grouping)
        if skuText.isEmpty || !SKUGenerator.prefixMatches(sku: skuText, type: stoneType, shapeString: shapeText, grouping: grouping) {
            skuText = suggestedSKU
        }
    }

    private func groupingFromCode(_ code: String) -> IntakeGrouping {
        switch code {
        case "P": return .pair
        case "L": return .lot
        default: return .single
        }
    }

    private func performSave(stay: Bool) {
        guard saveCurrent() else { return }
        lastStoneTypeRaw = stoneTypeText
        lastTreatment = treatment
        showSuccessFeedback()
        if !stay {
            resetForNextIntake()
            focusedField = .carats
        }
    }

    @State private var lastSavedStone: Gemstone?

    private func performSaveDuplicate() {
        guard saveCurrent() else { return }
        guard let prev = lastSavedStone else { return }
        stoneTypeText = prev.stoneType.rawValue
        shapeText = prev.shape ?? "Round"
        treatment = prev.treatment ?? prev.origin
        hasCert = prev.hasCert ?? false
        grouping = groupingFromCode(prev.grouping ?? "S")
        if prev.stoneType == .diamond {
            color = prev.color == "-" ? "" : prev.color
            clarity = prev.clarity == "-" ? "" : prev.clarity
            cut = prev.cut == "-" ? "EX" : prev.cut
            polish = prev.polish ?? "EX"
            symmetry = prev.symmetry ?? "EX"
            fluorescence = prev.fluorescence ?? "N"
        }
        caratsText = ""
        // Compute SKU from prev values directly to avoid SwiftUI state-update timing issues
        skuText = SKUGenerator.generateSKU(type: prev.stoneType, shape: prev.shape ?? "Round", grouping: groupingFromCode(prev.grouping ?? "S"), modelContext: modelContext)
        certLab = ""
        certNo = ""
        lengthText = ""
        widthText = ""
        heightText = ""
        costText = ""
        sellText = ""
        focusedField = .carats
        showSuccessFeedback()
    }

    private func resetForNextIntake() {
        caratsText = ""
        hasCert = false
        color = ""
        clarity = ""
        cut = "EX"
        polish = "EX"
        symmetry = "EX"
        fluorescence = "N"
        certLab = ""
        certNo = ""
        lengthText = ""
        widthText = ""
        heightText = ""
        costText = ""
        sellText = ""
        stoneTypeText = StoneType(rawValue: lastStoneTypeRaw)?.rawValue ?? "Diamond"
        treatment = lastTreatment
        shapeText = "Round"
        grouping = .single
        skuText = suggestedSKU
    }

    @discardableResult
    private func saveCurrent() -> Bool {
        guard let carat = carats, carat > 0 else { return false }
        var colorVal = color
        var clarityVal = clarity
        var cutVal = cut
        var polishVal = polish
        var symmetryVal = symmetry
        var fluorescenceVal = fluorescence
        if stoneType != .diamond {
            colorVal = "-"
            clarityVal = "-"
            cutVal = "-"
            polishVal = "-"
            symmetryVal = "-"
            fluorescenceVal = "-"
        }
        let groupingStr = SKUGenerator.groupingCode(grouping)

        if let g = gemstone {
            g.status = statusOverride
            g.stoneType = stoneType
            g.caratWeight = carat
            g.color = colorVal
            g.clarity = clarityVal
            g.cut = cutVal
            g.origin = treatment
            g.costPrice = costDecimal ?? 0
            g.sellPrice = sellDecimal ?? 0
            g.shape = shapeText
            g.treatment = treatment
            g.hasCert = hasCert
            g.grouping = groupingStr
            g.certLab = (hasCert && !certLab.isEmpty) ? certLab : nil
            g.certNo = (hasCert && !certNo.isEmpty) ? certNo : nil
            g.length = lengthVal
            g.width = widthVal
            g.height = heightVal
            g.polish = polishVal
            g.symmetry = symmetryVal
            g.fluorescence = fluorescenceVal
            g.sku = SKUGenerator.resolveSKUForEdit(existingSKU: g.sku, type: stoneType, shape: shapeText, grouping: grouping, modelContext: modelContext)
            logEvent(stone: g, type: .dateAdded, message: "Updated", modelContext: modelContext)
        } else {
            let sku = SKUGenerator.resolveSKUForSave(candidateSKU: skuText, type: stoneType, shape: shapeText, grouping: grouping, modelContext: modelContext)
            let stone = Gemstone(
                sku: sku,
                stoneType: stoneType,
                caratWeight: carat,
                color: colorVal,
                clarity: clarityVal,
                cut: cutVal,
                origin: treatment,
                costPrice: costDecimal ?? 0,
                sellPrice: sellDecimal ?? 0,
                shape: shapeText,
                treatment: treatment,
                hasCert: hasCert,
                grouping: groupingStr,
                certLab: certLab.isEmpty ? nil : certLab,
                certNo: certNo.isEmpty ? nil : certNo,
                length: lengthVal,
                width: widthVal,
                height: heightVal,
                polish: polishVal,
                symmetry: symmetryVal,
                fluorescence: fluorescenceVal
            )
            modelContext.insert(stone)
            logEvent(stone: stone, type: .dateAdded, message: "Added via Quick Intake", modelContext: modelContext)
            lastSavedStone = stone
        }
        do {
            try modelContext.save()
            return true
        } catch {
            return false
        }
    }

    private func showSuccessFeedback() {
        showSuccess = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.8))
            showSuccess = false
        }
    }
}
