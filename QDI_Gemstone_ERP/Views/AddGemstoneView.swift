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
    @State private var saveError: String?
    
    var body: some View {
        Form {
            Section {
                TextField("SKU", text: $sku)
                    .glassField()
                Picker("Type", selection: $stoneType) {
                    ForEach(StoneType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
            } header: {
                Text("IDENTIFICATION")
                    .sectionLabel()
            }

            Section {
                TextField("Carat Weight", text: $caratWeight)
                    .glassField()
                TextField("Color", text: $color)
                    .glassField()
                TextField("Clarity", text: $clarity)
                    .glassField()
                TextField("Cut", text: $cut)
                    .glassField()
                TextField("Origin", text: $origin)
                    .glassField()
            } header: {
                Text("SPECIFICATIONS")
                    .sectionLabel()
            }

            Section {
                TextField("Cost Price ($)", text: $costPrice)
                    .glassField()
                TextField("Sell Price ($)", text: $sellPrice)
                    .glassField()
            } header: {
                Text("PRICING")
                    .sectionLabel()
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .foregroundStyle(AppColors.ink)
        .frame(minWidth: 400, minHeight: 450)
        .background(AppColors.background)
        .navigationTitle("Add Gemstone")
        .alert("Save Error", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "An unknown error occurred.")
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .foregroundStyle(Color.white.opacity(0.40))
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { saveStone() }
                    .buttonStyle(GradientButtonStyle())
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
            saveError = "Failed to save gemstone: \(error.localizedDescription)"
        }
    }
}
