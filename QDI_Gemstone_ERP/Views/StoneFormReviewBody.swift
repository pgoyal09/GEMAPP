import SwiftUI
import SwiftData

extension StoneFormView {

    var reviewFormBody: some View {
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

    var reviewHeaderSection: some View {
        HStack(alignment: .center, spacing: AppSpacing.m) {
            VStack(alignment: .leading, spacing: 4) {
                Text("SKU")
                    .captionLabel()
                TextField("SKU", text: $skuText)
                    .glassField(violet: true)
                    .frame(width: 140)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Stone Type")
                    .captionLabel()
                AutocompleteFieldView(label: "", text: $stoneTypeText, options: stoneTypeOptions, placeholder: "Diamond", showLabel: false)
            }
            .frame(width: 130)
            VStack(alignment: .leading, spacing: 4) {
                Text("Status")
                    .captionLabel()
                Text(statusOverride.rawValue)
                    .frame(width: 110, alignment: .leading)
                    .padding(.vertical, 6)
                    .foregroundStyle(AppColors.inkMuted)
            }
            Spacer()
            HStack(spacing: AppSpacing.s) {
                Button("Save") {
                    if saveCurrent() {
                        showSuccessFeedback()
                    }
                }
                .disabled(!canSave)
                .buttonStyle(OutlineGlassButtonStyle())
                .keyboardShortcut(.defaultAction)
                Button("Save + Next") {
                    if saveCurrent() {
                        showSuccessFeedback()
                        onSaveAndNext?()
                    }
                }
                .disabled(!canSave || !hasNextInReview)
                .buttonStyle(GradientButtonStyle(gradient: AppColors.violetGradient))
                if let onDismiss {
                    Button("Done") { onDismiss() }
                        .buttonStyle(OutlineGlassButtonStyle())
                }
            }
        }
        .padding(AppSpacing.m)
        .glassCardBackground()
    }

    var editFormBody: some View {
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

    var editHeaderSection: some View {
        HStack(alignment: .center, spacing: AppSpacing.m) {
            VStack(alignment: .leading, spacing: 4) {
                Text("SKU")
                    .captionLabel()
                TextField("SKU", text: $skuText)
                    .glassField(violet: true)
                    .frame(width: 140)
                    .onSubmit { validateSKUChangeIfNeeded() }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Stone Type")
                    .captionLabel()
                AutocompleteFieldView(label: "", text: $stoneTypeText, options: stoneTypeOptions, placeholder: "Diamond", showLabel: false)
            }
            .frame(width: 130)
            VStack(alignment: .leading, spacing: 4) {
                Text("Status")
                    .captionLabel()
                Text(statusOverride.rawValue)
                    .frame(width: 110, alignment: .leading)
                    .padding(.vertical, 6)
                    .foregroundStyle(AppColors.inkMuted)
            }
            Spacer()
            if gemstone != nil {
                Button("Regenerate SKU") {
                    skuText = suggestedSKU
                }
                .buttonStyle(OutlineGlassButtonStyle())
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
                    .buttonStyle(OutlineGlassButtonStyle())
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
                .buttonStyle(GradientButtonStyle())
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(AppSpacing.m)
        .glassCardBackground()
    }

    var editLeftColumn: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Text("CORE IDENTITY")
                .textCase(.uppercase)
                .sectionLabel(tracking: 1.2)
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
                .tint(AppColors.primary)
            }
            editField("Carat", binding: $caratsText)
            editField("Treatment") {
                TextField("", text: $treatment)
                    .glassField()
                    .disabled(isDiamondLot)
            }
            if isNonDiamondLot {
                editField("Quality", binding: $qualityText)
            }
            editField("Certified") {
                Picker("", selection: $hasCert) {
                    Text("No").tag(false)
                    Text("Yes").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .tint(AppColors.primary)
                .disabled(isDiamondLot)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.m)
        .glassCardBackground()
    }

    var editRightColumn: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Text("DETAIL / COMMERCIAL")
                .textCase(.uppercase)
                .sectionLabel(tracking: 1.2)
            editField("Cert Lab") {
                TextField("", text: $certLab)
                    .glassField()
                    .disabled(certFieldsDisabled)
            }
            .opacity(certFieldsDisabled ? 0.6 : 1)
            editField("Cert No") {
                TextField("", text: $certNo)
                    .glassField()
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
            // Rapaport
            Text("RAPAPORT")
                .textCase(.uppercase)
                .sectionLabel(tracking: 1.2)
                .padding(.top, AppSpacing.s)
            HStack(spacing: AppSpacing.s) {
                editField("Rap Price", binding: $rapPriceText)
                editField("Rap Discount %", binding: $rapDiscountText)
            }
            // Multi-Currency
            Text("MULTI-CURRENCY")
                .textCase(.uppercase)
                .sectionLabel(tracking: 1.2)
                .padding(.top, AppSpacing.s)
            HStack(spacing: AppSpacing.s) {
                editField("Currency") {
                    TextField("USD", text: $purchaseCurrency)
                        .glassField()
                }
                editField("Amount", binding: $purchaseAmountText)
                editField("Exchange Rate", binding: $exchangeRateText)
            }
            // GIA
            editField("GIA Report #", binding: $giaReportNumber)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.m)
        .glassCardBackground()
    }
}
