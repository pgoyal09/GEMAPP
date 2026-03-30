import SwiftUI
import SwiftData

extension StoneFormView {

    func loadFromGemstoneOrDefaults() {
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
            sizeText = (grouping == .lot) ? (g.size ?? "") : ""
            qualityText = (grouping == .lot && stoneType != .diamond) ? (g.quality ?? "") : ""
            rapPriceText = g.rapPrice.map { "\($0)" } ?? ""
            rapDiscountText = g.rapDiscount.map { String(format: "%.1f", $0) } ?? ""
            purchaseCurrency = g.purchaseCurrency ?? "USD"
            purchaseAmountText = g.purchaseAmount.map { "\($0)" } ?? ""
            exchangeRateText = g.exchangeRate.map { String(format: "%.4f", $0) } ?? ""
            giaReportNumber = g.giaReportNumber ?? ""
            stoneImageData = g.imageData
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
            sizeText = ""
            qualityText = ""
            rapPriceText = ""
            rapDiscountText = ""
            purchaseCurrency = "USD"
            purchaseAmountText = ""
            exchangeRateText = ""
            giaReportNumber = ""
            stoneImageData = nil
        }
    }

    func validateSKUChangeIfNeeded() {
        guard mode == .edit, let g = gemstone, skuText != g.sku else { return }
        pendingSaveAfterSKUConfirm = false
        pendingSKURevert = g.sku
        showSKUChangeConfirm = true
    }

    func commitSKUChange() {
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

    func refreshSKUIfNeeded() {
        guard mode == .intake else { return }
        let expected = SKUGenerator.expectedPrefix(type: stoneType, shapeString: shapeText, grouping: grouping)
        if skuText.isEmpty || !SKUGenerator.prefixMatches(sku: skuText, type: stoneType, shapeString: shapeText, grouping: grouping) {
            skuText = suggestedSKU
        }
    }

    func groupingFromCode(_ code: String) -> IntakeGrouping {
        switch code {
        case "P": return .pair
        case "L": return .lot
        default: return .single
        }
    }

    func performSave(stay: Bool) {
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

    func performSaveDuplicate() {
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

    func resetForNextIntake() {
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
        sizeText = ""
        qualityText = ""
        rapPriceText = ""
        rapDiscountText = ""
        purchaseCurrency = "USD"
        purchaseAmountText = ""
        exchangeRateText = ""
        giaReportNumber = ""
        stoneImageData = nil
    }

    @discardableResult
    func saveCurrent() -> Bool {
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
        if isDiamondLot {
            cutVal = "-"
            polishVal = "-"
            symmetryVal = "-"
            fluorescenceVal = "-"
        }
        let groupingStr = SKUGenerator.groupingCode(grouping)

        if let g = gemstone {
            g.stoneType = stoneType
            g.caratWeight = carat
            g.color = colorVal
            g.clarity = clarityVal
            g.cut = cutVal
            g.origin = isDiamondLot ? "" : treatment
            g.costPrice = costDecimal ?? 0
            g.sellPrice = sellDecimal ?? 0
            g.shape = shapeText
            g.treatment = isDiamondLot ? nil : (treatment.isEmpty ? nil : treatment)
            g.hasCert = isDiamondLot ? false : hasCert
            g.grouping = groupingStr
            g.certLab = (hasCert && !certLab.isEmpty && !isDiamondLot) ? certLab : nil
            g.certNo = (hasCert && !certNo.isEmpty && !isDiamondLot) ? certNo : nil
            g.length = isDiamondLot ? nil : lengthVal
            g.width = isDiamondLot ? nil : widthVal
            g.height = isDiamondLot ? nil : heightVal
            g.length2 = (grouping == .pair && !isDiamondLot) ? length2Val : nil
            g.width2 = (grouping == .pair && !isDiamondLot) ? width2Val : nil
            g.height2 = (grouping == .pair && !isDiamondLot) ? height2Val : nil
            g.polish = polishVal
            g.symmetry = symmetryVal
            g.fluorescence = fluorescenceVal
            g.size = isDiamondLot ? (sizeText.isEmpty ? nil : sizeText) : nil
            g.quality = isNonDiamondLot ? (qualityText.isEmpty ? nil : qualityText) : nil
            g.certificateImagePath = certificateImagePath.isEmpty ? nil : certificateImagePath
            g.mediaPaths = mediaPathsLocal
            g.sku = SKUGenerator.resolveSKUForEdit(candidateSKU: skuText, existingSKU: g.sku, type: stoneType, shape: shapeText, grouping: grouping, modelContext: modelContext, excludingID: g.id)
            g.rapPrice = Decimal(string: rapPriceText)
            g.rapDiscount = Double(rapDiscountText)
            g.purchaseCurrency = purchaseCurrency.isEmpty ? nil : purchaseCurrency
            g.purchaseAmount = Decimal(string: purchaseAmountText)
            g.exchangeRate = Double(exchangeRateText)
            g.giaReportNumber = giaReportNumber.isEmpty ? nil : giaReportNumber
            g.imageData = stoneImageData
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
                length: isDiamondLot ? nil : lengthVal,
                width: isDiamondLot ? nil : widthVal,
                height: isDiamondLot ? nil : heightVal,
                length2: (grouping == .pair && !isDiamondLot) ? length2Val : nil,
                width2: (grouping == .pair && !isDiamondLot) ? width2Val : nil,
                height2: (grouping == .pair && !isDiamondLot) ? height2Val : nil,
                polish: polishVal,
                symmetry: symmetryVal,
                fluorescence: fluorescenceVal,
                size: isDiamondLot ? (sizeText.isEmpty ? nil : sizeText) : nil,
                quality: isNonDiamondLot ? (qualityText.isEmpty ? nil : qualityText) : nil
            )
            stone.rapPrice = Decimal(string: rapPriceText)
            stone.rapDiscount = Double(rapDiscountText)
            stone.purchaseCurrency = purchaseCurrency.isEmpty ? nil : purchaseCurrency
            stone.purchaseAmount = Decimal(string: purchaseAmountText)
            stone.exchangeRate = Double(exchangeRateText)
            stone.giaReportNumber = giaReportNumber.isEmpty ? nil : giaReportNumber
            stone.imageData = stoneImageData
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

    func showSuccessFeedback() {
        showSuccess = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.8))
            showSuccess = false
        }
    }
}
