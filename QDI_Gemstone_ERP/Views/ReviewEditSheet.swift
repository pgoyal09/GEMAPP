import SwiftUI
import SwiftData

struct ReviewEditSheet: View {
    let stone: Gemstone
    var onDismiss: () -> Void
    @Environment(\.modelContext) private var modelContext
    @State private var certLab: String = ""
    @State private var certNo: String = ""
    @State private var lengthText: String = ""
    @State private var widthText: String = ""
    @State private var heightText: String = ""
    @State private var costText: String = ""
    @State private var sellText: String = ""
    @State private var color: String = ""
    @State private var clarity: String = ""
    @State private var cut: String = ""
    @State private var polish: String = ""
    @State private var symmetry: String = ""
    @State private var fluorescence: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Cert") {
                    TextField("Cert Lab", text: $certLab)
                    TextField("Cert No", text: $certNo)
                }
                Section("Dimensions") {
                    HStack {
                        TextField("L", text: $lengthText)
                        TextField("W", text: $widthText)
                        TextField("H", text: $heightText)
                    }
                }
                if stone.stoneType == .diamond {
                    Section("Diamond Grading") {
                        TextField("Color", text: $color)
                        TextField("Clarity", text: $clarity)
                        TextField("Cut", text: $cut)
                        TextField("Polish", text: $polish)
                        TextField("Symmetry", text: $symmetry)
                        TextField("Fluorescence", text: $fluorescence)
                    }
                }
                Section("Pricing") {
                    TextField("Cost", text: $costText)
                    TextField("Sell Price", text: $sellText)
                }
            }
            .formStyle(.grouped)
            .frame(minWidth: 400, minHeight: 400)
            .navigationTitle("Complete: \(stone.sku)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                        onDismiss()
                    }
                }
            }
            .onAppear {
                certLab = stone.certLab ?? ""
                certNo = stone.certNo ?? ""
                lengthText = stone.length.map { String(format: "%.2f", $0) } ?? ""
                widthText = stone.width.map { String(format: "%.2f", $0) } ?? ""
                heightText = stone.height.map { String(format: "%.2f", $0) } ?? ""
                costText = stone.costPrice != 0 ? "\(stone.costPrice)" : ""
                sellText = stone.sellPrice != 0 ? "\(stone.sellPrice)" : ""
                color = stone.color
                clarity = stone.clarity
                cut = stone.cut
                polish = stone.polish ?? ""
                symmetry = stone.symmetry ?? ""
                fluorescence = stone.fluorescence ?? ""
            }
        }
    }

    private func save() {
        stone.certLab = certLab.isEmpty ? nil : certLab
        stone.certNo = certNo.isEmpty ? nil : certNo
        stone.length = Double(lengthText)
        stone.width = Double(widthText)
        stone.height = Double(heightText)
        stone.costPrice = Decimal(string: costText) ?? 0
        stone.sellPrice = Decimal(string: sellText) ?? 0
        stone.color = color.isEmpty ? stone.color : color
        stone.clarity = clarity.isEmpty ? stone.clarity : clarity
        stone.cut = cut.isEmpty ? stone.cut : cut
        stone.polish = polish.isEmpty ? nil : polish
        stone.symmetry = symmetry.isEmpty ? nil : symmetry
        stone.fluorescence = fluorescence.isEmpty ? nil : fluorescence
        try? modelContext.save()
    }
}
