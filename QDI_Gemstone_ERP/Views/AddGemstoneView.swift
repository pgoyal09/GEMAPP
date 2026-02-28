import SwiftUI
import SwiftData

struct AddGemstoneView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var sku = ""
    @State private var stoneType: StoneType = .diamond
    @State private var caratWeight = ""
    @State private var color = ""
    @State private var clarity = ""
    @State private var cut = ""
    @State private var origin = ""
    @State private var costPrice = ""
    @State private var sellPrice = ""
    
    var body: some View {
        Form {
            Section("Identification") {
                TextField("SKU", text: $sku)
                Picker("Type", selection: $stoneType) {
                    ForEach(StoneType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
            }
            
            Section("Specifications") {
                TextField("Carat Weight", text: $caratWeight)
                    .textFieldStyle(.roundedBorder)
                TextField("Color", text: $color)
                TextField("Clarity", text: $clarity)
                TextField("Cut", text: $cut)
                TextField("Origin", text: $origin)
            }
            
            Section("Pricing") {
                TextField("Cost Price ($)", text: $costPrice)
                    .textFieldStyle(.roundedBorder)
                TextField("Sell Price ($)", text: $sellPrice)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 400, minHeight: 450)
        .navigationTitle("Add Gemstone")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { saveStone() }
                    .disabled(!isValid)
            }
        }
    }
    
    private var isValid: Bool {
        !sku.isEmpty &&
        Double(caratWeight) != nil &&
        Decimal(string: costPrice) != nil &&
        Decimal(string: sellPrice) != nil
    }
    
    private func saveStone() {
        guard let carat = Double(caratWeight),
              let cost = Decimal(string: costPrice),
              let sell = Decimal(string: sellPrice) else { return }
        
        let stone = Gemstone(
            sku: sku.trimmingCharacters(in: .whitespaces),
            stoneType: stoneType,
            caratWeight: carat,
            color: color.isEmpty ? "-" : color,
            clarity: clarity.isEmpty ? "-" : clarity,
            cut: cut.isEmpty ? "-" : cut,
            origin: origin.isEmpty ? "-" : origin,
            costPrice: cost,
            sellPrice: sell
        )
        modelContext.insert(stone)
        logEvent(stone: stone, type: .dateAdded, message: "Added to inventory", modelContext: modelContext)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Failed to save gemstone: \(error)")
        }
    }
}
