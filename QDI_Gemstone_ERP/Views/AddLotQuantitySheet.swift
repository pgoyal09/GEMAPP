import SwiftUI
import SwiftData

struct AddLotQuantitySheet: View {
    let lot: Gemstone
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var caratsText = ""
    @State private var costPerCaratText = ""
    @State private var notes = ""
    @State private var date = Date()
    @State private var showValidationError = false
    @State private var validationMessage = ""

    private var parsedCarats: Double? {
        Double(caratsText.trimmingCharacters(in: .whitespaces))
    }
    private var parsedCostPerCarat: Decimal? {
        guard let d = Double(costPerCaratText.trimmingCharacters(in: .whitespaces)) else { return nil }
        return Decimal(d)
    }

    private var newAverageCost: Decimal? {
        guard let addCarats = parsedCarats, addCarats > 0,
              let addCost = parsedCostPerCarat else { return nil }
        let existingCarats = Decimal(lot.effectiveRemainingCarats)
        let existingCost = lot.effectiveAverageCost
        let totalCarats = existingCarats + Decimal(addCarats)
        guard totalCarats > 0 else { return addCost }
        return (existingCarats * existingCost + Decimal(addCarats) * addCost) / totalCarats
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add Quantity to Lot")
                        .font(.title2.bold())
                        .foregroundStyle(AppColors.ink)
                    Text("\(lot.sku) · \(lot.stoneType.rawValue) · Currently \(String(format: "%.2f ct", lot.effectiveRemainingCarats)) remaining")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.inkMuted)
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(OutlineGlassButtonStyle())
                GradientButton(title: "Add Quantity") { saveQuantity() }
                    .opacity(parsedCarats == nil || parsedCostPerCarat == nil ? 0.4 : 1.0)
                    .allowsHitTesting(parsedCarats != nil && parsedCostPerCarat != nil)
            }
            .padding(AppSpacing.l)

            Divider().overlay(AppColors.cardStroke)

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.l) {
                    HStack(spacing: AppSpacing.xl) {
                        formField("Carats to Add *", hint: "e.g. 5.00") {
                            TextField("0.00", text: $caratsText)
                                .glassField()
                                .frame(width: 120)
                        }
                        formField("Cost per Carat *", hint: "e.g. 800") {
                            TextField("0.00", text: $costPerCaratText)
                                .glassField()
                                .frame(width: 120)
                        }
                        formField("Date", hint: "") {
                            DatePicker("", selection: $date, displayedComponents: .date)
                                .labelsHidden()
                                .frame(width: 160)
                        }
                    }

                    formField("Notes (optional)", hint: "") {
                        TextField("e.g. New batch from supplier", text: $notes)
                            .glassField()
                            .frame(maxWidth: 400)
                    }

                    if let addCarats = parsedCarats, addCarats > 0,
                       let addCost = parsedCostPerCarat,
                       let newAvg = newAverageCost {
                        GlassCard {
                            VStack(alignment: .leading, spacing: AppSpacing.m) {
                                Text("Preview")
                                    .font(.headline)
                                    .foregroundStyle(AppColors.ink)
                                HStack(spacing: AppSpacing.xl) {
                                    previewStat("Carats Added", String(format: "+%.2f ct", addCarats), color: AppColors.success)
                                    previewStat("New Total", String(format: "%.2f ct", lot.effectiveRemainingCarats + addCarats), color: AppColors.primary)
                                    previewStat("Total Cost", (addCost * Decimal(addCarats)).asCurrency, color: AppColors.primary)
                                    previewStat("New Avg Cost/ct", newAvg.asCurrency, color: Color(red: 0.37, green: 0.51, blue: 0.98))
                                }
                            }
                        }
                    }
                }
                .padding(AppSpacing.l)
            }
        }
        .frame(minWidth: 600, minHeight: 300)
        .background(AppColors.background)
        .alert("Invalid Input", isPresented: $showValidationError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(validationMessage)
        }
    }

    private func formField<Content: View>(_ label: String, hint: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.inkMuted)
            content()
            if !hint.isEmpty {
                Text(hint).font(.caption2).foregroundStyle(AppColors.inkSubtle)
            }
        }
    }

    private func previewStat(_ label: String, _ value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.subheadline.bold()).foregroundStyle(color)
            Text(label).font(.caption).foregroundStyle(AppColors.inkMuted)
        }
    }

    private func saveQuantity() {
        guard let addCarats = parsedCarats, addCarats > 0 else {
            validationMessage = "Please enter a valid number of carats."
            showValidationError = true
            return
        }
        guard let addCostPerCarat = parsedCostPerCarat, addCostPerCarat > 0 else {
            validationMessage = "Please enter a valid cost per carat."
            showValidationError = true
            return
        }

        // Compute new weighted average cost
        let existingCarats = Decimal(lot.effectiveRemainingCarats)
        let existingCost = lot.effectiveAverageCost
        let totalCarats = existingCarats + Decimal(addCarats)
        let newAvgCost = totalCarats > 0
            ? (existingCarats * existingCost + Decimal(addCarats) * addCostPerCarat) / totalCarats
            : addCostPerCarat

        // Update lot
        lot.remainingCarats = lot.effectiveRemainingCarats + addCarats
        lot.caratWeight += addCarats
        lot.averageCostPerCarat = newAvgCost

        // Record transaction
        let txn = LotTransaction(
            type: .added,
            carats: addCarats,
            date: date,
            pricePerCarat: addCostPerCarat,
            totalPrice: addCostPerCarat * Decimal(addCarats),
            notes: notes.isEmpty ? nil : notes,
            gemstone: lot
        )
        modelContext.insert(txn)

        do {
            try modelContext.save()
        } catch {
            validationMessage = "Failed to save: \(error.localizedDescription)"
            showValidationError = true
            return
        }
        dismiss()
    }
}
