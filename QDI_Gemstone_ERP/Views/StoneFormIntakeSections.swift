import SwiftUI

extension StoneFormView {

    var intakeHeader: some View {
        HStack {
            Text("Quick Intake")
                .font(.headline)
                .foregroundStyle(AppColors.ink)
            Spacer()
        }
    }

    var row1: some View {
        HStack(spacing: AppSpacing.m) {
            AutocompleteFieldView(label: "Stone Type", text: $stoneTypeText, options: stoneTypeOptions, placeholder: "Diamond")
            AutocompleteFieldView(label: "Shape", text: $shapeText, options: shapeOptions, placeholder: "Round")
            groupingPicker
        }
    }

    var groupingPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Single / Pair / Lot")
                .captionLabel()
            Picker("", selection: $grouping) {
                ForEach(IntakeGrouping.allCases) { g in
                    Text(g.rawValue).tag(g)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .tint(AppColors.primary)
        }
    }

    var row2: some View {
        HStack(spacing: AppSpacing.m) {
            caratsField
            treatmentField
            if isNonDiamondLot {
                qualityField
            }
            certToggle
        }
    }

    var qualityField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Quality")
                .captionLabel()
            TextField("", text: $qualityText)
                .glassField()
                .focused($focusedField, equals: .quality)
        }
    }

    var caratsField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Carats")
                .captionLabel()
            TextField("0.00", text: $caratsText)
                .glassField()
                .focused($focusedField, equals: .carats)
        }
    }

    var treatmentField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Treatment")
                .captionLabel()
            TextField("", text: $treatment)
                .glassField()
                .focused($focusedField, equals: .treatment)
                .disabled(isDiamondLot)
        }
    }

    var certToggle: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Cert")
                .captionLabel()
            Picker("", selection: $hasCert) {
                Text("No").tag(false)
                Text("Yes").tag(true)
            }
            .pickerStyle(.segmented)
            .tint(AppColors.primary)
            .disabled(isDiamondLot)
            .labelsHidden()
        }
    }

    var skuField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("SKU")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.tanzaniteColor.opacity(0.70))
            TextField("Auto", text: $skuText)
                .glassField(violet: true)
                .focused($focusedField, equals: .sku)
        }
    }

    @ViewBuilder
    var saveButtons: some View {
        HStack(spacing: AppSpacing.m) {
            switch mode {
            case .intake:
                Button("Save") { performSave(stay: true) }
                    .disabled(!canSave || isSavingInProgress)
                    .buttonStyle(OutlineGlassButtonStyle())
                Button("Save + Next") { performSave(stay: false) }
                    .disabled(!canSave || isSavingInProgress)
                    .buttonStyle(GradientButtonStyle())
                    .keyboardShortcut(.defaultAction)
                Button("Save + Dup Prev") { performSaveDuplicate() }
                    .disabled(!canSave || isSavingInProgress)
                    .buttonStyle(OutlineGlassButtonStyle())
            case .review:
                Button("Save") {
                    saveCurrent()
                    showSuccessFeedback()
                }
                .disabled(!canSave)
                .buttonStyle(OutlineGlassButtonStyle())
                Button("Save + Next") {
                    saveCurrent()
                    showSuccessFeedback()
                    onSaveAndNext?()
                }
                .disabled(!canSave || !hasNextInReview)
                .buttonStyle(GradientButtonStyle(gradient: AppColors.violetGradient))
                if let onDismiss {
                    Button("Done") { onDismiss() }
                        .buttonStyle(OutlineGlassButtonStyle())
                }
            case .edit:
                Button("Save") {
                    _ = saveCurrent()
                    showSuccessFeedback()
                    onSave?()
                }
                .disabled(!canSave)
                .buttonStyle(GradientButtonStyle())
                .keyboardShortcut(.defaultAction)
                if let onDismiss {
                    Button("Done") { onDismiss() }
                        .buttonStyle(OutlineGlassButtonStyle())
                }
            }
        }
    }

    var diamondSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            Text("DIAMOND GRADING")
                .textCase(.uppercase)
                .sectionLabel(tracking: 1.2)
            if isDiamondLot {
                HStack(spacing: AppSpacing.m) {
                    formField("Color", $color, .color, missing: isMissing(stoneType == .diamond && color.isEmpty))
                    formField("Clarity", $clarity, .clarity, missing: isMissing(stoneType == .diamond && clarity.isEmpty))
                    formField("Size", $sizeText, .size, missing: false)
                }
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: AppSpacing.m) {
                    formField("Color", $color, .color, missing: isMissing(stoneType == .diamond && color.isEmpty))
                    formField("Clarity", $clarity, .clarity, missing: isMissing(stoneType == .diamond && clarity.isEmpty))
                    formField("Cut", $cut, .cut, missing: false)
                    formField("Polish", $polish, .polish, missing: false)
                    formField("Symmetry", $symmetry, .symmetry, missing: false)
                    formField("Fluorescence", $fluorescence, .fluorescence, missing: false)
                }
            }
        }
        .padding(AppSpacing.l)
        .glassCardBackground(radius: AppCornerRadius.l)
    }

    func formField(_ label: String, _ binding: Binding<String>, _ field: StoneFormField, missing: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(AppTypography.caption)
                .foregroundStyle(missing ? AppColors.warning : Color.white.opacity(0.40))
            TextField("", text: binding)
                .glassField()
                .focused($focusedField, equals: field)
        }
    }

    var deferredSection: some View {
        DisclosureGroup("Deferred fields (Cert Lab, Dimensions, Cost, Sell)", isExpanded: $expandDeferred) {
            VStack(alignment: .leading, spacing: AppSpacing.s) {
            HStack(spacing: AppSpacing.m) {
                certLabField
                certNoField
                dimensionField("L", $lengthText, .len)
                    .disabled(isDiamondLot)
                dimensionField("W", $widthText, .wid)
                    .disabled(isDiamondLot)
                dimensionField("H", $heightText, .hei)
                    .disabled(isDiamondLot)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Cost")
                        .font(AppTypography.caption)
                        .foregroundStyle(isMissingCost() ? AppColors.warning : Color.white.opacity(0.40))
                    TextField("", text: $costText)
                        .glassField()
                        .focused($focusedField, equals: .cost)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sell Price")
                        .font(AppTypography.caption)
                        .foregroundStyle(isMissingSell() ? AppColors.warning : Color.white.opacity(0.40))
                    TextField("", text: $sellText)
                        .glassField()
                        .focused($focusedField, equals: .sell)
                }
            }
            if grouping == .pair {
                HStack(spacing: AppSpacing.m) {
                    Text("Stone 2:")
                        .captionLabel()
                    dimensionField("L", $length2Text, .len2)
                        .disabled(isDiamondLot)
                    dimensionField("W", $width2Text, .wid2)
                        .disabled(isDiamondLot)
                    dimensionField("H", $height2Text, .hei2)
                        .disabled(isDiamondLot)
                    Spacer()
                }
            }
            }
        }
        .foregroundStyle(AppColors.ink)
    }

    var certLabField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Cert Lab")
                .font(AppTypography.caption)
                .foregroundStyle(certFieldsDisabled ? Color.white.opacity(0.25) : (isMissingCertDetails() ? AppColors.warning : Color.white.opacity(0.40)))
            TextField("", text: $certLab)
                .glassField()
                .focused($focusedField, equals: .certLab)
                .disabled(certFieldsDisabled)
        }
    }

    var certNoField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Cert No")
                .font(AppTypography.caption)
                .foregroundStyle(certFieldsDisabled ? Color.white.opacity(0.25) : (isMissingCertDetails() ? AppColors.warning : Color.white.opacity(0.40)))
            TextField("", text: $certNo)
                .glassField()
                .focused($focusedField, equals: .certNo)
                .disabled(certFieldsDisabled)
        }
    }

    func dimensionField(_ label: String, _ binding: Binding<String>, _ field: StoneFormField) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .captionLabel()
            TextField("", text: binding)
                .glassField()
                .focused($focusedField, equals: field)
        }
    }
}
