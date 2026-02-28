import SwiftUI
import SwiftData

/// Inline-editable row for persisted LineItem. Updates model on change; totals recompute from lineItems.
struct EditableLineItemRow: View {
    let item: LineItem
    @Environment(\.modelContext) private var modelContext
    var onUpdate: (() -> Void)?
    
    @State private var descriptionText: String = ""
    @State private var caratsText: String = ""
    @State private var rateText: String = ""
    @State private var isSyncing = false
    
    private static var currencyFormatter: NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        return f
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Text(item.displaySku)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: LineItemColumnLayout.sku, alignment: .leading)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 4)

            TextField("Description", text: $descriptionText)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1)
                .frame(minWidth: LineItemColumnLayout.descriptionMin, maxWidth: .infinity, alignment: .leading)
                .onSubmit { commitDescription() }
                .padding(.horizontal, 4)

            if item.isService {
                Text("—")
                    .frame(width: LineItemColumnLayout.carats, alignment: .trailing)
                    .padding(.horizontal, 4)
            } else {
                TextField("Carats", text: $caratsText)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .frame(width: LineItemColumnLayout.carats, alignment: .trailing)
                    .onSubmit { commitCarats() }
                    .padding(.horizontal, 4)
            }

            if item.isService {
                TextField("Amount", text: $rateText)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .frame(width: LineItemColumnLayout.rate, alignment: .trailing)
                    .onSubmit { commitRateOrAmount() }
                    .padding(.horizontal, 4)
            } else {
                TextField("Rate", text: $rateText)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .frame(width: LineItemColumnLayout.rate, alignment: .trailing)
                    .onSubmit { commitRateOrAmount() }
                    .padding(.horizontal, 4)
            }

            Text(displayAmount)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: LineItemColumnLayout.amount, alignment: .trailing)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
        }
        .padding(.vertical, 6)
        .onAppear { syncFromItem() }
        .onChange(of: item.itemDescription) { _, _ in syncFromItem() }
        .onChange(of: item.carats) { _, _ in syncFromItem() }
        .onChange(of: item.rate) { _, _ in syncFromItem() }
    }
    
    private var displayAmount: String {
        let amt = item.isService ? item.rate : item.rate * Decimal(item.carats)
        return Self.currencyFormatter.string(from: amt as NSDecimalNumber) ?? "$0.00"
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
        do {
            try modelContext.save()
            onUpdate?()
        } catch {
            syncFromItem()
        }
    }
}
