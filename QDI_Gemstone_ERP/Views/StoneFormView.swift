import SwiftUI
import SwiftData
import UniformTypeIdentifiers

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
    var onDirtyStateChange: ((Bool) -> Void)?

    @Environment(\.modelContext) private var modelContext
    @AppStorage("QuickIntake.lastStoneType") private var lastStoneTypeRaw: String = StoneType.diamond.rawValue
    @AppStorage("QuickIntake.lastTreatment") private var lastTreatment: String = ""

    @State private var stoneTypeText: String = "Diamond"
    @State private var shapeText: String = "Round"
    @State private var grouping: IntakeGrouping = .single
    @State private var caratsText: String = ""
    @State private var treatment: String = ""
    @State private var hasCert: Bool = false
    @State private var skuText: String = ""
    @State private var expandDeferred: Bool = true
    @State private var showSuccess: Bool = false
    @FocusState private var focusedField: StoneFormField?

    enum StoneFormField: Hashable {
        case stoneType, shape, carats, treatment, sku
        case color, clarity, cut, polish, symmetry, fluorescence
        case certLab, certNo, len, wid, hei, len2, wid2, hei2, cost, sell
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
    @State private var length2Text: String = ""
    @State private var width2Text: String = ""
    @State private var height2Text: String = ""
    @State private var costText: String = ""
    @State private var sellText: String = ""
    @State private var statusOverride: GemstoneStatus = .available
    @State private var certificateImagePath: String = ""
    @State private var mediaPathsLocal: [String] = []
    @State private var showCertImagePicker = false
    @State private var showMediaPicker = false
    @State private var showLeaveWithoutSavingAlert = false
    @State private var showSKUChangeConfirm = false
    @State private var showSKUDuplicateError = false
    @State private var pendingSKURevert: String?
    @State private var pendingSaveAfterSKUConfirm = false

    private var stoneType: StoneType { StoneType(rawValue: stoneTypeText) ?? .diamond }
    private var carats: Double? { Double(caratsText) }
    private var costDecimal: Decimal? { Decimal(string: costText) }
    private var sellDecimal: Decimal? { Decimal(string: sellText) }
    private var lengthVal: Double? { Double(lengthText) }
    private var widthVal: Double? { Double(widthText) }
    private var heightVal: Double? { Double(heightText) }
    private var length2Val: Double? { Double(length2Text) }
    private var width2Val: Double? { Double(width2Text) }
    private var height2Val: Double? { Double(height2Text) }

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

    /// True when user has entered content worth saving. Autofilled SKU/type/shape alone do not count.
    private var intakeFormHasContent: Bool {
        mode == .intake && !caratsText.isEmpty
    }

    private var hasUnsavedChanges: Bool {
        guard mode == .edit, let g = gemstone else { return false }
        // Status is read-only, not considered for unsaved changes
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
        .onChange(of: grouping) { _, _ in refreshSKUIfNeeded() }
        .alert("Leave without saving?", isPresented: $showLeaveWithoutSavingAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Leave", role: .destructive) {
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
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, AppSpacing.l)
                    .padding(.vertical, AppSpacing.m)
                    .background(Color.green)
                    .cornerRadius(AppCornerRadius.m)
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
    private var intakeReviewBody: some View {
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

    private var reviewFormBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                reviewHeaderSection
                HStack(alignment: .top, spacing: AppSpacing.l) {
                    editLeftColumn
                    editRightColumn
                }
                if stoneType == .diamond {
                    editDiamondSection
                }
                editCertificateMediaSection
            }
            .padding(AppSpacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var reviewHeaderSection: some View {
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
                Text(statusOverride.rawValue)
                    .frame(width: 110, alignment: .leading)
                    .padding(.vertical, 6)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: AppSpacing.s) {
                Button("Save") {
                    if saveCurrent() {
                        showSuccessFeedback()
                    }
                }
                .disabled(!canSave)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                Button("Save + Next") {
                    if saveCurrent() {
                        showSuccessFeedback()
                        onSaveAndNext?()
                    }
                }
                .disabled(!canSave || !hasNextInReview)
                if let onDismiss {
                    Button("Done") { onDismiss() }
                        .buttonStyle(.bordered)
                }
            }
        }
        .padding(AppSpacing.m)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(AppCornerRadius.m)
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
                editCertificateMediaSection
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
                    .onSubmit { validateSKUChangeIfNeeded() }
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
                Text(statusOverride.rawValue)
                    .frame(width: 110, alignment: .leading)
                    .padding(.vertical, 6)
                    .foregroundStyle(.secondary)
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
                    Button("Cancel") {
                        if hasUnsavedChanges {
                            showLeaveWithoutSavingAlert = true
                        } else {
                            onDismiss()
                        }
                    }
                    .keyboardShortcut(.cancelAction)
                }
                Button("Save") {
                    if mode == .edit, let g = gemstone, skuText != g.sku {
                        pendingSaveAfterSKUConfirm = true
                        pendingSKURevert = g.sku
                        showSKUChangeConfirm = true
                        return
                    }
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
            if grouping == .pair {
                HStack(spacing: AppSpacing.s) {
                    editField("L2", binding: $length2Text)
                    editField("W2", binding: $width2Text)
                    editField("H2", binding: $height2Text)
                }
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

    private var editCertificateMediaSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Text("Certificate Image & Media")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
            HStack(spacing: AppSpacing.s) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Certificate Image")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: AppSpacing.s) {
                        Text(certificateImagePath.isEmpty ? "No file selected" : (certificateImagePath as NSString).lastPathComponent)
                            .font(.body)
                            .foregroundStyle(certificateImagePath.isEmpty ? .secondary : .primary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button("Choose...") {
                            DispatchQueue.main.async { showCertImagePicker = true }
                        }
                            .buttonStyle(.bordered)
                    }
                }
                Spacer()
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Media")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: AppSpacing.s) {
                    Button("Add Media...") { showMediaPicker = true }
                        .buttonStyle(.bordered)
                    if !mediaPathsLocal.isEmpty {
                        Text("\(mediaPathsLocal.count) file(s)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if !mediaPathsLocal.isEmpty {
                    ForEach(Array(mediaPathsLocal.enumerated()), id: \.offset) { idx, path in
                        HStack {
                            Text((path as NSString).lastPathComponent)
                                .font(.caption)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Button { mediaPathsLocal.remove(at: idx) } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.m)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(AppCornerRadius.m)
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
            TextField("", text: $treatment)
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
                    .disabled(!canSave || isSavingInProgress)
                Button("Save + Next") { performSave(stay: false) }
                    .disabled(!canSave || isSavingInProgress)
                    .keyboardShortcut(.defaultAction)
                Button("Save + Dup Prev") { performSaveDuplicate() }
                    .disabled(!canSave || isSavingInProgress)
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
            VStack(alignment: .leading, spacing: AppSpacing.s) {
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
            if grouping == .pair {
                HStack(spacing: AppSpacing.m) {
                    Text("Stone 2:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    dimensionField("L", $length2Text, .len2)
                    dimensionField("W", $width2Text, .wid2)
                    dimensionField("H", $height2Text, .hei2)
                    Spacer()
                }
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
            treatment = (g.treatment ?? g.origin) ?? ""
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
            length2Text = g.length2.map { String(format: "%.2f", $0) } ?? ""
            width2Text = g.width2.map { String(format: "%.2f", $0) } ?? ""
            height2Text = g.height2.map { String(format: "%.2f", $0) } ?? ""
            costText = g.costPrice != 0 ? "\(g.costPrice)" : ""
            sellText = g.sellPrice != 0 ? "\(g.sellPrice)" : ""
            certificateImagePath = g.certificateImagePath ?? ""
            mediaPathsLocal = g.mediaPaths
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
            length2Text = ""
            width2Text = ""
            height2Text = ""
            costText = ""
            sellText = ""
            certificateImagePath = ""
            mediaPathsLocal = []
        }
    }

    private func validateSKUChangeIfNeeded() {
        guard mode == .edit, let g = gemstone, skuText != g.sku else { return }
        pendingSaveAfterSKUConfirm = false
        pendingSKURevert = g.sku
        showSKUChangeConfirm = true
    }

    private func commitSKUChange() {
        let revert = pendingSKURevert
        pendingSKURevert = nil
        showSKUChangeConfirm = false
        let shouldSave = pendingSaveAfterSKUConfirm
        pendingSaveAfterSKUConfirm = false

        let exists = SKUGenerator.skuExists(sku: skuText, excludingID: gemstone?.id, modelContext: modelContext)
        if exists {
            showSKUDuplicateError = true
            if let r = revert { skuText = r }
            return
        }
        if shouldSave, saveCurrent() {
            showSuccessFeedback()
            onSave?()
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
        guard !isSavingInProgress else { return }
        guard saveCurrent() else { return }
        isSavingInProgress = true
        lastStoneTypeRaw = stoneTypeText
        lastTreatment = treatment
        showSuccessFeedback()
        if !stay {
            resetForNextIntake()
            focusedField = .carats
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            isSavingInProgress = false
        }
    }

    @State private var lastSavedStone: Gemstone?
    @State private var isSavingInProgress = false

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
        length2Text = prev.length2.map { String(format: "%.2f", $0) } ?? ""
        width2Text = prev.width2.map { String(format: "%.2f", $0) } ?? ""
        height2Text = prev.height2.map { String(format: "%.2f", $0) } ?? ""
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
        length2Text = ""
        width2Text = ""
        height2Text = ""
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
            // Status is system-managed; do not overwrite from form
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
            g.length2 = grouping == .pair ? length2Val : nil
            g.width2 = grouping == .pair ? width2Val : nil
            g.height2 = grouping == .pair ? height2Val : nil
            g.polish = polishVal
            g.symmetry = symmetryVal
            g.fluorescence = fluorescenceVal
            g.certificateImagePath = certificateImagePath.isEmpty ? nil : certificateImagePath
            g.mediaPaths = mediaPathsLocal
            g.sku = SKUGenerator.resolveSKUForEdit(candidateSKU: skuText, existingSKU: g.sku, type: stoneType, shape: shapeText, grouping: grouping, modelContext: modelContext, excludingID: g.id)
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
                length2: grouping == .pair ? length2Val : nil,
                width2: grouping == .pair ? width2Val : nil,
                height2: grouping == .pair ? height2Val : nil,
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
