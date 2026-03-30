import SwiftUI
import SwiftData

/// Inline-editable row for persisted LineItem. Updates model on change; totals recompute from lineItems.
struct EditableLineItemRow: View {
    let item: LineItem
    /// When false, updates stay in memory until explicit Save (draft mode).
    var persistOnEdit: Bool = true
    @Environment(\.modelContext) private var modelContext
    var onUpdate: (() -> Void)?
    
    @State private var descriptionText: String = ""
    @State private var caratsText: String = ""
    @State private var rateText: String = ""
    @State private var isSyncing = false
    
    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Text(item.displaySku)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: LineItemColumnLayout.sku, alignment: .leading)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(AppColors.primary.opacity(0.80))
                .padding(.horizontal, 4)

            Group {
                if item.gemstone == nil && !item.isService {
                    Picker("", selection: Binding(
                        get: { item.brokeredStoneType ?? "" },
                        set: {
                            item.brokeredStoneType = $0.isEmpty ? nil : $0
                            onUpdate?()
                        }
                    )) {
                        Text("—").tag("")
                        ForEach(StoneType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                } else {
                    Text(item.stoneTypeDisplay)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundStyle(AppColors.inkMuted)
                }
            }
            .frame(width: LineItemColumnLayout.stoneType, alignment: .leading)
            .padding(.horizontal, 4)

            TextField("Description", text: $descriptionText, axis: .vertical)
                .textFieldStyle(.plain)
                .foregroundStyle(AppColors.ink)
                .lineLimit(1...10)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .frame(minWidth: LineItemColumnLayout.descriptionMin, maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(AppColors.panelBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(AppColors.cardStroke, lineWidth: 1)
                        )
                )
                .onSubmit { commitDescription() }
                .padding(.horizontal, 4)

            if item.isService {
                Text("—")
                    .foregroundStyle(AppColors.inkSubtle)
                    .frame(width: LineItemColumnLayout.carats, alignment: .trailing)
                    .padding(.horizontal, 4)
            } else {
                TextField("Carats", text: $caratsText)
                    .textFieldStyle(.plain)
                    .foregroundStyle(AppColors.ink)
                    .multilineTextAlignment(.trailing)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .frame(width: LineItemColumnLayout.carats, alignment: .trailing)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(AppColors.panelBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(AppColors.cardStroke, lineWidth: 1)
                            )
                    )
                    .onSubmit { commitCarats() }
                    .padding(.horizontal, 4)
            }

            if item.isService {
                TextField("Amount", text: $rateText)
                    .textFieldStyle(.plain)
                    .foregroundStyle(AppColors.ink)
                    .multilineTextAlignment(.trailing)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .frame(width: LineItemColumnLayout.rate, alignment: .trailing)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(AppColors.panelBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(AppColors.cardStroke, lineWidth: 1)
                            )
                    )
                    .onSubmit { commitRateOrAmount() }
                    .padding(.horizontal, 4)
            } else {
                TextField("Rate", text: $rateText)
                    .textFieldStyle(.plain)
                    .foregroundStyle(AppColors.ink)
                    .multilineTextAlignment(.trailing)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .frame(width: LineItemColumnLayout.rate, alignment: .trailing)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(AppColors.panelBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(AppColors.cardStroke, lineWidth: 1)
                            )
                    )
                    .onSubmit { commitRateOrAmount() }
                    .padding(.horizontal, 4)
            }

            Text(displayAmount)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: LineItemColumnLayout.amount, alignment: .trailing)
                .foregroundStyle(AppColors.ink)
                .padding(.horizontal, 4)
        }
        .padding(.vertical, 6)
        .onAppear { syncFromItem() }
        .onChange(of: item.itemDescription) { _, _ in syncFromItem() }
        .onChange(of: item.carats) { _, _ in syncFromItem() }
        .onChange(of: item.rate) { _, _ in syncFromItem() }
        .onChange(of: descriptionText) { _, newVal in
            if !isSyncing {
                item.itemDescription = newVal
                onUpdate?()
            }
        }
        .onChange(of: caratsText) { _, val in
            guard !isSyncing, !val.isEmpty, let v = Double(val), v >= 0 else { return }
            item.carats = v
            if !item.isService { item.amount = item.rate * Decimal(v) }
            onUpdate?()
        }
        .onChange(of: rateText) { _, val in
            guard !isSyncing, !val.isEmpty, let d = Decimal(string: val), d >= 0 else { return }
            item.rate = d
            item.amount = item.isService ? d : d * Decimal(item.carats)
            onUpdate?()
        }
    }
    
    private var displayAmount: String {
        let amt = item.isService ? item.rate : item.rate * Decimal(item.carats)
        return amt.asCurrency
    }
    
    private func syncFromItem() {
        isSyncing = true
        defer { isSyncing = false }
        descriptionText = item.itemDescription
        caratsText = item.isService ? "" : String(format: "%.2f", item.carats)
        rateText = "\(item.rate)"
    }
    
    private func commitDescription() {
        item.itemDescription = descriptionText
        saveAndNotify()
    }
    
    private func commitCarats() {
        let v = Double(caratsText) ?? 0
        item.carats = max(0, v)
        if !item.isService {
            item.amount = item.rate * Decimal(item.carats)
        }
        caratsText = String(format: "%.2f", item.carats)
        saveAndNotify()
    }
    
    private func commitRateOrAmount() {
        guard let d = Decimal(string: rateText), d >= 0 else { return }
        item.rate = d
        if item.isService {
            item.amount = d
        } else {
            item.amount = d * Decimal(item.carats)
        }
        saveAndNotify()
    }
    
    private func saveAndNotify() {
        if persistOnEdit {
            do {
                try modelContext.save()
            } catch {
                syncFromItem()
                return
            }
        }
        onUpdate?()
    }
}
