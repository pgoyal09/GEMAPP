import SwiftUI
import SwiftData

/// Single-stone quick intake form with essential fields visible by default
/// and an expandable advanced section for less-used fields.
struct QuickIntakeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var stoneType: StoneType = .diamond
    @State private var shapeText = ""
    @State private var caratText = ""
    @State private var colorText = ""
    @State private var clarityText = ""
    @State private var costPriceText = ""
    @State private var sellPriceText = ""

    // Advanced fields
    @State private var showAdvanced = false
    @State private var lengthText = ""
    @State private var widthText = ""
    @State private var heightText = ""
    @State private var certLab = ""
    @State private var certNo = ""
    @State private var rfidEPC = ""
    @State private var cutText = ""
    @State private var fluorescenceText = ""
    @State private var origin = ""
    @State private var treatment = ""

    @State private var isSaving = false
    @State private var toastMessage: String?
    @State private var toastIsError = false
    @State private var isDirty = false
    @State private var showDiscardAlert = false

    @FocusState private var focusedField: Field?

    // Autocomplete suggestions
    private let shapeOptions = StoneShape.allCases.map(\.rawValue)
    private let colorOptions = GemstoneColorOption.allowed
    private let clarityOptions = GemstoneClarityOption.allowed
    private let cutOptions = ["Excellent", "Very Good", "Good", "Fair", "Poor"]
    private let fluorescenceOptions = ["None", "Faint", "Medium", "Strong", "Very Strong"]

    private enum Field: Hashable {
        case shape, carat, color, clarity, cost, sell
        case length, width, height, certLab, certNo, rfid, cut, fluorescence, origin, treatment
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.section) {
                    essentialSection
                    advancedToggle
                    if showAdvanced {
                        advancedSection
                    }
                }
                .padding(AppSpacing.hero)
            }
            bottomToolbar
        }
        .overlay {
            if let msg = toastMessage {
                ToastOverlay(message: msg, isError: toastIsError)
                    .animation(reduceMotion ? nil : AppAnimation.standard, value: toastMessage)
            }
        }
        .onAppear { focusedField = .carat }
        .onChange(of: caratText) { _, _ in isDirty = true }
        .onChange(of: shapeText) { _, _ in isDirty = true }
        .onChange(of: colorText) { _, _ in isDirty = true }
        .onChange(of: clarityText) { _, _ in isDirty = true }
        .onChange(of: costPriceText) { _, _ in isDirty = true }
        .onChange(of: sellPriceText) { _, _ in isDirty = true }
        .alert("Unsaved Changes", isPresented: $showDiscardAlert) {
            Button("Discard", role: .destructive) { dismiss() }
            Button("Cancel", role: .cancel) { }
        }
    }

    // MARK: - Essential Fields

    private var essentialSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.comfortable) {
            SectionHeader(title: "Stone Details")

            HStack(spacing: AppSpacing.standard) {
                pickerField("Type", selection: $stoneType) {
                    ForEach(StoneType.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                autocompleteField("Shape", text: $shapeText, options: shapeOptions, focus: .shape)
                numericField("Carat", text: $caratText, focus: .carat)
            }

            HStack(spacing: AppSpacing.standard) {
                autocompleteField("Color", text: $colorText, options: colorOptions, focus: .color)
                autocompleteField("Clarity", text: $clarityText, options: clarityOptions, focus: .clarity)
                numericField("Cost $", text: $costPriceText, focus: .cost)
                numericField("Sell $", text: $sellPriceText, focus: .sell)
            }
        }
        .padding(AppSpacing.section)
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                .fill(AppColors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                .strokeBorder(AppColors.cardStroke, lineWidth: 1)
        )
    }

    // MARK: - Advanced Toggle

    private var advancedToggle: some View {
        Button {
            withAnimation(reduceMotion ? nil : AppAnimation.standard) {
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
    }

    // MARK: - Advanced Fields

    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.comfortable) {
            SectionHeader(title: "Advanced")

            HStack(spacing: AppSpacing.standard) {
                numericField("Length (mm)", text: $lengthText, focus: .length)
                numericField("Width (mm)", text: $widthText, focus: .width)
                numericField("Height (mm)", text: $heightText, focus: .height)
            }

            HStack(spacing: AppSpacing.standard) {
                labeledField("Cert Lab", text: $certLab, focus: .certLab)
                labeledField("Cert No.", text: $certNo, focus: .certNo)
            }

            HStack(spacing: AppSpacing.standard) {
                labeledField("RFID EPC", text: $rfidEPC, focus: .rfid)
            }

            HStack(spacing: AppSpacing.standard) {
                autocompleteField("Cut Grade", text: $cutText, options: cutOptions, focus: .cut)
                autocompleteField("Fluorescence", text: $fluorescenceText, options: fluorescenceOptions, focus: .fluorescence)
            }

            HStack(spacing: AppSpacing.standard) {
                labeledField("Origin", text: $origin, focus: .origin)
                labeledField("Treatment", text: $treatment, focus: .treatment)
            }
        }
        .padding(AppSpacing.section)
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                .fill(AppColors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                .strokeBorder(AppColors.cardStroke, lineWidth: 1)
        )
    }

    // MARK: - Bottom Toolbar

    private var bottomToolbar: some View {
        HStack {
            Spacer()
            Button("Cancel") {
                    if isDirty { showDiscardAlert = true } else { dismiss() }
                }
                .buttonStyle(.outline)
                .disabled(isSaving)
                .keyboardShortcut(.escape, modifiers: [])

            Button("Save & New") {
                save(continueAdding: true)
            }
            .buttonStyle(.outline(AppColors.primary))
            .disabled(!canSave || isSaving)

            Button("Save") {
                save(continueAdding: false)
            }
            .buttonStyle(.gradient)
            .disabled(!canSave || isSaving)
            .keyboardShortcut("s", modifiers: .command)
        }
        .padding(AppSpacing.section)
        .background(AppColors.panelBackground)
        .overlay(alignment: .top) { Divider().background(AppColors.cardElevated) }
    }

    // MARK: - Field Builders

    private func labeledField(_ label: String, text: Binding<String>, focus: Field) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.compact) {
            Text(label)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.inkSubtle)
            TextField(label, text: text)
                .textFieldStyle(.plain)
                .font(AppTypography.body)
                .padding(.horizontal, AppSpacing.standard)
                .frame(height: 28)
                .background(
                    RoundedRectangle(cornerRadius: AppCornerRadius.field, style: .continuous)
                        .fill(AppColors.cardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppCornerRadius.field, style: .continuous)
                        .strokeBorder(AppColors.cardStroke, lineWidth: 1)
                )
                .focused($focusedField, equals: focus)
        }
    }

    private func numericField(_ label: String, text: Binding<String>, focus: Field) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.compact) {
            Text(label)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.inkSubtle)
            TextField(label, text: text)
                .textFieldStyle(.plain)
                .font(AppTypography.body)
                .padding(.horizontal, AppSpacing.standard)
                .frame(height: 28)
                .multilineTextAlignment(.trailing)
                .background(
                    RoundedRectangle(cornerRadius: AppCornerRadius.field, style: .continuous)
                        .fill(AppColors.cardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppCornerRadius.field, style: .continuous)
                        .strokeBorder(AppColors.cardStroke, lineWidth: 1)
                )
                .focused($focusedField, equals: focus)
        }
    }

    private func autocompleteField(_ label: String, text: Binding<String>, options: [String], focus: Field) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.compact) {
            Text(label)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.inkSubtle)
            AutocompleteTextField(text: text, options: options, label: label)
                .focused($focusedField, equals: focus)
        }
    }

    private func pickerField<S: Hashable, C: View>(_ label: String, selection: Binding<S>, @ViewBuilder content: @escaping () -> C) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.compact) {
            Text(label)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.inkSubtle)
            Picker(label, selection: selection, content: content)
                .labelsHidden()
                .frame(height: 28)
        }
    }

    // MARK: - Validation & Save

    private var canSave: Bool {
        let carat = Double(caratText) ?? 0
        return carat > 0
    }

    private func save(continueAdding: Bool) {
        guard !isSaving, canSave else { return }
        isSaving = true
        defer { isSaving = false }

        let carat = Double(caratText) ?? 0
        let cost = Decimal(string: costPriceText) ?? 0
        let sell = Decimal(string: sellPriceText) ?? 0

        let sku = SKUGenerator.generate(
            type: stoneType,
            shape: shapeText,
            grouping: .single,
            modelContext: modelContext
        )

        let stone = Gemstone(
            sku: sku,
            stoneType: stoneType,
            caratWeight: carat,
            shape: shapeText,
            origin: origin,
            color: colorText,
            clarity: clarityText,
            treatment: treatment,
            hasCert: !certLab.isEmpty,
            certLab: certLab,
            certNo: certNo,
            costPrice: cost,
            sellPrice: sell
        )

        // Advanced fields
        stone.cut = cutText.nilIfEmpty ?? ""
        stone.fluorescence = fluorescenceText.nilIfEmpty ?? ""
        if let l = Double(lengthText) { stone.length = l }
        if let w = Double(widthText) { stone.width = w }
        if let h = Double(heightText) { stone.height = h }

        modelContext.insert(stone)
        NotificationCenter.default.post(name: .dataStoreDidChange, object: nil)

        toastIsError = false
        toastMessage = "Saved \(sku)"

        isDirty = false
        if continueAdding {
            resetFields()
            focusedField = .carat
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { dismiss() }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation(reduceMotion ? nil : .default) { toastMessage = nil }
        }
    }

    private func resetFields() {
        shapeText = ""
        caratText = ""
        colorText = ""
        clarityText = ""
        costPriceText = ""
        sellPriceText = ""
        lengthText = ""
        widthText = ""
        heightText = ""
        certLab = ""
        certNo = ""
        rfidEPC = ""
        cutText = ""
        fluorescenceText = ""
        origin = ""
        treatment = ""
    }
}

