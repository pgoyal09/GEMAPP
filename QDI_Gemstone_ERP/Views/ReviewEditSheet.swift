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
                Section {
                    TextField("Cert Lab", text: $certLab)
                        .glassField()
                    TextField("Cert No", text: $certNo)
                        .glassField()
                } header: {
                    Text("CERT")
                        .sectionLabel()
                }
                Section {
                    HStack {
                        TextField("L", text: $lengthText)
                            .glassField()
                        TextField("W", text: $widthText)
                            .glassField()
                        TextField("H", text: $heightText)
                            .glassField()
                    }
                } header: {
                    Text("DIMENSIONS")
                        .sectionLabel()
                }
                if stone.stoneType == .diamond {
                    Section {
                        TextField("Color", text: $color)
                            .glassField()
                        TextField("Clarity", text: $clarity)
                            .glassField()
                        TextField("Cut", text: $cut)
                            .glassField()
                        TextField("Polish", text: $polish)
                            .glassField()
                        TextField("Symmetry", text: $symmetry)
                            .glassField()
                        TextField("Fluorescence", text: $fluorescence)
                            .glassField()
                    } header: {
                        Text("DIAMOND GRADING")
                            .sectionLabel()
                    }
                }
                Section {
                    TextField("Cost", text: $costText)
                        .glassField()
                    TextField("Sell Price", text: $sellText)
                        .glassField()
                } header: {
                    Text("PRICING")
                        .sectionLabel()
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .foregroundStyle(AppColors.ink)
            .frame(minWidth: 400, minHeight: 400)
            .background(AppColors.background)
            .navigationTitle("Complete: \(stone.sku)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
                        .foregroundStyle(Color.white.opacity(0.40))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                        onDismiss()
                    }
                    .buttonStyle(GradientButtonStyle())
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
