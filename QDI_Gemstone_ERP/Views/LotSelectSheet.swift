import SwiftUI
import SwiftData

/// Sheet to pick a lot stone and specify carats for a memo or invoice line item.
struct LotSelectSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var selectedLotID: PersistentIdentifier?
    @State private var caratsText = ""
    @State private var searchText = ""
    @State private var showValidation = false
    @State private var validationMessage = ""

    var onSelect: (Gemstone, Double) -> Void

    @Query(sort: \Gemstone.sku) private var allGemstones: [Gemstone]

    private var lotStones: [Gemstone] {
        var result = allGemstones.filter { $0.grouping == "L" && $0.effectiveRemainingCarats > 0 }
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            result = result.filter {
                $0.sku.lowercased().contains(q) ||
                $0.stoneType.rawValue.lowercased().contains(q) ||
                $0.color.lowercased().contains(q)
            }
        }
        return result
    }

    private var selectedLot: Gemstone? {
        guard let id = selectedLotID else { return nil }
        return allGemstones.first { $0.id == id }
    }

    private var parsedCarats: Double? {
        guard let val = Double(caratsText.trimmingCharacters(in: .whitespaces)), val > 0 else { return nil }
        return val
    }

    private var canConfirm: Bool {
        guard let lot = selectedLot, let carats = parsedCarats else { return false }
        return carats <= lot.effectiveRemainingCarats
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Select Lot")
                        .font(.headline)
                        .foregroundStyle(AppColors.ink)
                    Text("Choose a lot and enter the carat amount to allocate.")
                        .font(.caption)
                        .foregroundStyle(AppColors.inkMuted)
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(OutlineGlassButtonStyle())
                Button("Add to Line Items") { confirmSelection() }
                    .buttonStyle(GradientButtonStyle())
                    .disabled(!canConfirm)
            }
            .padding(.horizontal, AppSpacing.l)
            .padding(.vertical, AppSpacing.m)

            Divider().overlay(AppColors.cardStroke)

            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(Color.white.opacity(0.25))
                TextField("Search lots…", text: $searchText)
                    .textFieldStyle(.plain)
                    .foregroundStyle(AppColors.ink)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Color.white.opacity(0.40))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppSpacing.m)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
            .padding(AppSpacing.m)

            HStack(spacing: 0) {
                Color.clear.frame(width: 24)
                Text("SKU").frame(width: 100, alignment: .leading).padding(.horizontal, 4)
                Text("Type").frame(width: 90, alignment: .leading).padding(.horizontal, 4)
                Text("Color / Clarity").frame(width: 160, alignment: .leading).padding(.horizontal, 4)
                Text("Shape").frame(width: 100, alignment: .leading).padding(.horizontal, 4)
                Text("Available").frame(width: 90, alignment: .trailing).padding(.horizontal, 4)
                Text("Sell/ct").frame(width: 90, alignment: .trailing).padding(.horizontal, 4)
                Spacer()
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(AppColors.inkSubtle)
            .tracking(0.5)
            .padding(.horizontal, AppSpacing.m)
            .padding(.vertical, 5)
            .background(AppColors.cardBackground)

            Divider().overlay(AppColors.cardStroke)

            if lotStones.isEmpty {
                ContentUnavailableView(
                    "No Lots Available",
                    systemImage: "cube.box",
                    description: Text("There are no lots with remaining carats.")
                )
                .foregroundStyle(AppColors.inkMuted)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $selectedLotID) {
                    ForEach(lotStones) { lot in
                        lotRow(lot)
                            .tag(lot.id)
                            .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.m, bottom: 0, trailing: AppSpacing.m))
                            .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }

            Divider().overlay(AppColors.cardStroke)

            if let lot = selectedLot {
                HStack(spacing: AppSpacing.l) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Carats to allocate from \(lot.sku)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppColors.inkMuted)
                        HStack(spacing: AppSpacing.m) {
                            TextField("0.00", text: $caratsText)
                                .glassField()
                                .frame(width: 120)
                            Text("of \(String(format: "%.2f ct", lot.effectiveRemainingCarats)) available")
                                .font(.caption)
                                .foregroundStyle(AppColors.inkMuted)
                        }
                    }
                    Spacer()
                    if let carats = parsedCarats {
                        let amount = lot.sellPrice * Decimal(carats)
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(amount.asCurrency)
                                .font(.title3.bold())
                                .foregroundStyle(AppColors.ink)
                            Text("Total amount")
                                .font(.caption)
                                .foregroundStyle(AppColors.inkMuted)
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.l)
                .padding(.vertical, AppSpacing.m)
                .background(AppColors.primary.opacity(0.08))
            }
        }
        .frame(minWidth: 680, minHeight: 460)
        .background(AppColors.background)
        .alert("Invalid Input", isPresented: $showValidation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(validationMessage)
        }
    }

    private func lotRow(_ lot: Gemstone) -> some View {
        HStack(spacing: 0) {
            Image(systemName: selectedLotID == lot.id ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(selectedLotID == lot.id ? AppColors.primary : AppColors.inkSubtle)
                .frame(width: 24)
            Text(lot.sku)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(AppColors.ink)
                .frame(width: 100, alignment: .leading)
                .padding(.horizontal, 4)
            Text(lot.stoneType.rawValue)
                .foregroundStyle(AppColors.ink)
                .frame(width: 90, alignment: .leading)
                .padding(.horizontal, 4)
            VStack(alignment: .leading, spacing: 0) {
                Text(lot.color.isEmpty ? "—" : lot.color)
                    .foregroundStyle(AppColors.ink)
                Text(lot.clarity.isEmpty ? "—" : lot.clarity)
                    .font(.caption)
                    .foregroundStyle(AppColors.inkMuted)
            }
            .frame(width: 160, alignment: .leading)
            .padding(.horizontal, 4)
            Text(lot.shape ?? "—")
                .foregroundStyle(AppColors.ink)
                .frame(width: 100, alignment: .leading)
                .padding(.horizontal, 4)
            Text(String(format: "%.2f ct", lot.effectiveRemainingCarats))
                .foregroundStyle(lot.effectiveRemainingCarats < 1.0 ? AppColors.warning : AppColors.ink)
                .frame(width: 90, alignment: .trailing)
                .padding(.horizontal, 4)
            Text(lot.sellPrice.asCurrency)
                .foregroundStyle(AppColors.ink)
                .frame(width: 90, alignment: .trailing)
                .padding(.horizontal, 4)
            Spacer()
        }
        .padding(.vertical, 8)
        .background(selectedLotID == lot.id ? AppColors.primary.opacity(0.10) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedLotID = lot.id
            if caratsText.isEmpty {
                caratsText = ""
            }
        }
    }

    private func confirmSelection() {
        guard let lot = selectedLot else {
            validationMessage = "Please select a lot."
            showValidation = true
            return
        }
        guard let carats = parsedCarats else {
            validationMessage = "Please enter a valid carat amount."
            showValidation = true
            return
        }
        guard carats <= lot.effectiveRemainingCarats else {
            validationMessage = "Cannot allocate \(String(format: "%.2f", carats)) ct — only \(String(format: "%.2f", lot.effectiveRemainingCarats)) ct available."
            showValidation = true
            return
        }
        onSelect(lot, carats)
        dismiss()
    }
}
