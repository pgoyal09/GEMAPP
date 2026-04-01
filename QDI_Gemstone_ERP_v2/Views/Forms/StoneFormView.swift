import SwiftUI
import SwiftData

struct StoneFormView: View {
    @State var viewModel: StoneFormViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isCaratFieldFocused: Bool
    @State private var isSaving = false
    @State private var showAdvanced = false
    var navigateTo: Binding<NavigationItem>?

    init(mode: StoneFormMode, navigateTo: Binding<NavigationItem>? = nil) {
        _viewModel = State(initialValue: StoneFormViewModel(mode: mode))
        self.navigateTo = navigateTo
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.hero) {
                    identitySection
                    essentialGradingSection
                    certificationSection
                    pricingSection

                    // Advanced toggle
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showAdvanced.toggle()
                        }
                    } label: {
                        HStack(spacing: AppSpacing.compact) {
                            Image(systemName: showAdvanced ? "chevron.up" : "chevron.down")
                            Text(showAdvanced ? "Hide Advanced" : "Show Advanced")
                        }
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.primary)
                    }
                    .buttonStyle(.plain)

                    if showAdvanced {
                        gradingSection
                        if viewModel.isDiamond { diamondAdvancedSection }
                        if !viewModel.isDiamond { gemstoneSection }
                        if viewModel.isLot { lotSection }
                        dimensionsSection
                        rapNetSection
                    }
                }
                .padding(AppSpacing.hero)
            }
            bottomToolbar
        }
        .onAppear {
            if case .intake = viewModel.mode {
                viewModel.refreshSKU(modelContext: modelContext)
            }
            isCaratFieldFocused = true
        }
        .alert("SKU Already Exists", isPresented: $viewModel.showSKUConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Use Anyway") { viewModel.commitSKUChange() }
        } message: {
            Text("A stone with SKU '\(viewModel.pendingSKU)' already exists.")
        }
        .alert("Zero Price", isPresented: $viewModel.showZeroPriceConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Save Anyway") {
                do {
                    try viewModel.save(modelContext: modelContext)
                    if viewModel.toastIsError == false {
                        if let nav = navigateTo {
                            nav.wrappedValue = viewModel.isDiamond ? .diamonds :
                                viewModel.isLot ? .lots : .gemstones
                        } else {
                            dismiss()
                        }
                    }
                } catch {
                    viewModel.toastMessage = "Save failed: \(ErrorMapper.userMessage(from: error))"
                    viewModel.toastIsError = true
                }
            }
        } message: {
            Text("Stone has $0 price. Save anyway?")
        }
        .onChange(of: viewModel.caratText) { _, _ in viewModel.validateInline() }
        .onChange(of: viewModel.shapeText) { _, _ in viewModel.validateInline() }
        .onChange(of: viewModel.costPriceText) { _, _ in viewModel.validateInline() }
        .onChange(of: viewModel.sellPriceText) { _, _ in viewModel.validateInline() }
        .onChange(of: viewModel.rapNetDiscountPctText) { _, _ in viewModel.validateInline() }
        .onChange(of: viewModel.cashDiscountPctText) { _, _ in viewModel.validateInline() }
        .interactiveDismissDisabled(isSaving)
        .overlay {
            if let msg = viewModel.toastMessage {
                ToastOverlay(message: msg, isError: viewModel.toastIsError)
                    .animation(reduceMotion ? nil : .easeInOut, value: viewModel.toastMessage)
            }
        }
    }

    // MARK: - Identity

    private var identitySection: some View {
        GlassCard(padding: AppSpacing.section) {
            VStack(alignment: .leading, spacing: AppSpacing.comfortable) {
                SectionHeader(title: "Stone Identity")
                HStack(spacing: AppSpacing.section) {
                    FormField(label: "SKU", text: $viewModel.sku)
                        .font(AppTypography.mono)
                        .disabled(!viewModel.mode.isEditing && viewModel.mode.existingStone == nil)
                        .accessibilitySortPriority(10)
                    FormPicker(label: "Type", selection: $viewModel.stoneTypeText) {
                        ForEach(StoneType.allCases, id: \.self) { Text($0.rawValue).tag($0.rawValue) }
                    }
                    .onChange(of: viewModel.stoneTypeText) { _, _ in viewModel.refreshSKU(modelContext: modelContext) }
                    .accessibilitySortPriority(9)
                    FormField(label: "Shape", text: $viewModel.shapeText, error: viewModel.shapeError)
                        .onChange(of: viewModel.shapeText) { _, _ in viewModel.refreshSKU(modelContext: modelContext) }
                        .accessibilitySortPriority(8)
                    FormPicker(label: "Grouping", selection: $viewModel.grouping) {
                        ForEach(StoneGrouping.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    .help("Single stone, Pair, Lot (group sold by total weight), Melee (small stones under 0.20ct), or Parcel (collection of grouped stones)")
                    .onChange(of: viewModel.grouping) { _, _ in viewModel.refreshSKU(modelContext: modelContext) }
                    .accessibilitySortPriority(7)
                }
                HStack(spacing: AppSpacing.section) {
                    FormField(label: "Carats", text: $viewModel.caratText, error: viewModel.caratError)
                        .focused($isCaratFieldFocused)
                        .accessibilitySortPriority(6)
                    FormField(label: "Origin", text: $viewModel.origin)
                        .accessibilitySortPriority(5)
                }
            }
        }
    }

    // MARK: - Essential Grading (Color, Clarity — always visible)

    private var essentialGradingSection: some View {
        GlassCard(padding: AppSpacing.section) {
            VStack(alignment: .leading, spacing: AppSpacing.comfortable) {
                SectionHeader(title: viewModel.isDiamond ? "Diamond Grading" : "Grading")
                HStack(spacing: AppSpacing.section) {
                    field("Color", $viewModel.color).accessibilitySortPriority(4)
                    field("Clarity", $viewModel.clarity).accessibilitySortPriority(3)
                }
            }
        }
    }

    // MARK: - Grading (Advanced)

    private var gradingSection: some View {
        GlassCard(padding: AppSpacing.section) {
            VStack(alignment: .leading, spacing: AppSpacing.comfortable) {
                SectionHeader(title: "Treatment")
                HStack(spacing: AppSpacing.section) {
                    field("Treatment", $viewModel.treatment)
                }
            }
        }
    }

    // MARK: - Diamond Advanced

    private var diamondAdvancedSection: some View {
        GlassCard(padding: AppSpacing.section) {
            VStack(alignment: .leading, spacing: AppSpacing.comfortable) {
                SectionHeader(title: "Diamond Details")
                HStack(spacing: AppSpacing.section) {
                    field("Cut", $viewModel.cut).accessibilitySortPriority(2)
                    field("Polish", $viewModel.polish)
                    field("Symmetry", $viewModel.symmetry)
                }
                HStack(spacing: AppSpacing.section) {
                    field("Fluorescence", $viewModel.fluorescence)
                    field("Fluor. Intensity", $viewModel.fluorescenceIntensity)
                    field("Fluor. Color", $viewModel.fluorescenceColor)
                }
                HStack(spacing: AppSpacing.section) {
                    field("Eye Clean", $viewModel.eyeClean)
                    field("Depth %", $viewModel.depthPctText)
                    field("Table %", $viewModel.tablePctText)
                }
                HStack(spacing: AppSpacing.section) {
                    field("Fancy Color", $viewModel.fancyColor)
                    field("Fancy Intensity", $viewModel.fancyColorIntensity)
                    field("Fancy Overtone", $viewModel.fancyColorOvertone)
                }
                HStack(spacing: AppSpacing.section) {
                    field("RapNet Price", $viewModel.rapNetPriceText)
                    field("RapNet Disc %", $viewModel.rapNetDiscountPctText, error: viewModel.rapNetDiscountError)
                    field("Cash Price", $viewModel.cashPriceText)
                    field("Cash Disc %", $viewModel.cashDiscountPctText, error: viewModel.cashDiscountError)
                }
            }
        }
    }

    // MARK: - Gemstone-Specific

    private var gemstoneSection: some View {
        GlassCard(padding: AppSpacing.section) {
            VStack(alignment: .leading, spacing: AppSpacing.comfortable) {
                SectionHeader(title: "Gemstone Grading")
                HStack(spacing: AppSpacing.section) {
                    field("Color", $viewModel.color)
                    field("Clarity", $viewModel.clarity)
                }
                HStack(spacing: AppSpacing.section) {
                    field("Primary Color", $viewModel.primaryColorVendor)
                    field("Color Intensity", $viewModel.colorIntensityVendor)
                }
                HStack(spacing: AppSpacing.section) {
                    field("Color Modifiers", $viewModel.colorModifiersVendor)
                    field("Color Description", $viewModel.colorDescription)
                }
                HStack(spacing: AppSpacing.section) {
                    field("Treatment 2", $viewModel.treatmentType2)
                    field("Treatment 3", $viewModel.treatmentType3)
                }
                HStack(spacing: AppSpacing.section) {
                    field("Treatment Notes", $viewModel.treatmentNotes)
                    field("# of Stones", $viewModel.numberOfStonesText)
                }
            }
        }
    }

    // MARK: - Lot-Specific

    private var lotSection: some View {
        GlassCard(padding: AppSpacing.section) {
            VStack(alignment: .leading, spacing: AppSpacing.comfortable) {
                SectionHeader(title: "Lot Details")
                    .help("A group of similar stones sold by total carat weight")
                HStack(spacing: AppSpacing.section) {
                    field("Size Range", $viewModel.size)
                    field("Quality", $viewModel.quality)
                }
            }
        }
    }

    // MARK: - Certification

    private var certificationSection: some View {
        GlassCard(padding: AppSpacing.section) {
            VStack(alignment: .leading, spacing: AppSpacing.comfortable) {
                SectionHeader(title: "Certification")
                Toggle("Has Certificate", isOn: $viewModel.hasCert)
                    .toggleStyle(.checkbox)
                    .foregroundStyle(AppColors.inkMuted)
                    .accessibilityLabel("Has Certificate")
                if viewModel.hasCert {
                    HStack(spacing: AppSpacing.section) {
                        field("Lab", $viewModel.certLab)
                        field("Cert No.", $viewModel.certNo)
                    }
                }
            }
        }
    }

    // MARK: - Dimensions

    private var dimensionsSection: some View {
        GlassCard(padding: AppSpacing.section) {
            VStack(alignment: .leading, spacing: AppSpacing.comfortable) {
                SectionHeader(title: "Dimensions (mm)")
                HStack(spacing: AppSpacing.section) {
                    field("Length", $viewModel.lengthText)
                    field("Width", $viewModel.widthText)
                    field("Height", $viewModel.heightText)
                }
                if viewModel.isPair {
                    HStack(spacing: AppSpacing.section) {
                        field("Length 2", $viewModel.length2Text)
                        field("Width 2", $viewModel.width2Text)
                        field("Height 2", $viewModel.height2Text)
                    }
                }
            }
        }
    }

    // MARK: - Pricing

    private var pricingSection: some View {
        GlassCard(padding: AppSpacing.section) {
            VStack(alignment: .leading, spacing: AppSpacing.comfortable) {
                SectionHeader(title: "Pricing")
                HStack(spacing: AppSpacing.section) {
                    field("Cost Price", $viewModel.costPriceText, error: viewModel.costPriceError)
                    field("Sell Price", $viewModel.sellPriceText, error: viewModel.sellPriceError)
                }
                HStack(spacing: AppSpacing.section) {
                    FormPicker(label: "Currency", selection: $viewModel.currencyType) {
                        ForEach(CurrencyType.allCases, id: \.self) { c in
                            Text(c.rawValue).tag(c)
                        }
                    }
                    field("Exchange Rate", $viewModel.exchangeRateText)
                }
                // Computed pricing display
                if let stone = viewModel.mode.existingStone {
                    VStack(alignment: .leading, spacing: AppSpacing.compact) {
                        if let rap = stone.rapNetCalculatedPrice {
                            DetailRow(label: "RapNet Calc $/ct", value: rap.asCurrency)
                        }
                        if let ppc = stone.perCaratPrice {
                            DetailRow(label: "Per Carat Price", value: ppc.asCurrency)
                        }
                        if stone.currencyType != .usd {
                            DetailRow(
                                label: "Sell (\(stone.currencyType.rawValue))",
                                value: "\(stone.currencyType.symbol)\(stone.sellPriceInDisplayCurrency)"
                            )
                        }
                    }
                }
            }
        }
    }

    // MARK: - RapNet / Listing

    private var rapNetSection: some View {
        GlassCard(padding: AppSpacing.section) {
            VStack(alignment: .leading, spacing: AppSpacing.comfortable) {
                SectionHeader(title: "Listing Details")
                HStack(spacing: AppSpacing.section) {
                    field("Availability", $viewModel.availability)
                    field("Video URL", $viewModel.videoUrl)
                }
                HStack(spacing: AppSpacing.section) {
                    field("Country", $viewModel.stoneCountry)
                    field("State", $viewModel.stoneState)
                    field("City", $viewModel.stoneCity)
                }
            }
        }
    }

    // MARK: - Bottom Toolbar

    private var bottomToolbar: some View {
        HStack {
            Spacer()
            Button("Cancel") { dismiss() }
                .buttonStyle(.outline)
                .disabled(isSaving)
                .keyboardShortcut(.escape, modifiers: [])

            if case .intake = viewModel.mode {
                Button("Save & Continue") {
                    guard !isSaving else { return }
                    isSaving = true
                    defer { isSaving = false }
                    do {
                        try viewModel.saveAndContinue(modelContext: modelContext)
                    } catch {
                        viewModel.toastMessage = "Save failed: \(ErrorMapper.userMessage(from: error))"
                        viewModel.toastIsError = true
                    }
                }
                .buttonStyle(.outline(AppColors.primary))
                .disabled(isSaving)
            }

            Button("Save") {
                guard !isSaving else { return }
                isSaving = true
                defer { isSaving = false }
                do {
                    try viewModel.saveWithPriceCheck(modelContext: modelContext)
                    if viewModel.toastIsError == false && !viewModel.showZeroPriceConfirmation {
                        if let nav = navigateTo {
                            nav.wrappedValue = viewModel.isDiamond ? .diamonds :
                                viewModel.isLot ? .lots : .gemstones
                        } else {
                            dismiss()
                        }
                    }
                } catch {
                    viewModel.toastMessage = "Save failed: \(ErrorMapper.userMessage(from: error))"
                    viewModel.toastIsError = true
                }
            }
            .buttonStyle(.gradient)
            .disabled(!viewModel.canSave || isSaving)
            .keyboardShortcut("s", modifiers: .command)
        }
        .padding(AppSpacing.section)
        .background(AppColors.panelBackground)
        .overlay(alignment: .top) { Divider().background(AppColors.cardElevated) }
    }

    // MARK: - Helper

    private func field(_ label: String, _ text: Binding<String>, error: String? = nil) -> some View {
        FormField(label: label, text: text, error: error)
    }
}
