import SwiftUI
import SwiftData

struct EditableLineItemRow: View {
    @Bindable var item: LineItem
    @Environment(\.modelContext) private var modelContext
    var rowNumber: Int = 0
    var widths: [CGFloat] = []
    var onUpdate: () -> Void = {}
    var onDelete: (() -> Void)? = nil

    @State private var descriptionText: String = ""
    @State private var caratsText: String = ""
    @State private var rateText: String = ""
    @State private var isSyncing = false

    private func w(_ index: Int) -> CGFloat {
        widths.indices.contains(index) ? widths[index] : 60
    }

    var body: some View {
        HStack(spacing: 4) {
            // Row number
            Text("\(rowNumber)")
                .font(AppTypography.mono)
                .foregroundStyle(AppColors.inkSubtle)
                .frame(width: 28, alignment: .center)

            // SKU
            Text(item.displaySku)
                .font(AppTypography.mono)
                .foregroundStyle(AppColors.inkMuted)
                .frame(width: w(0), alignment: .leading)

            // Stone Type
            if item.kind == .brokered {
                Picker("", selection: $item.brokeredStoneType) {
                    Text("—").tag("")
                    ForEach(StoneType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type.rawValue)
                    }
                }
                .labelsHidden()
                .frame(width: w(1))
            } else {
                Text(item.stoneTypeDisplay)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.inkMuted)
                    .frame(width: w(1), alignment: .leading)
            }

            // Description
            TextField("Description", text: $descriptionText)
                .textFieldStyle(.plain)
                .frame(width: w(2), alignment: .leading)
                .onChange(of: descriptionText) { _, val in
                    guard !isSyncing else { return }
                    item.itemDescription = val
                    onUpdate()
                }

            // Carats
            if item.kind == .service {
                Text("—")
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.inkSubtle)
                    .frame(width: w(3), alignment: .trailing)
            } else {
                TextField("0.00", text: $caratsText)
                    .textFieldStyle(.plain)
                    .frame(width: w(3), alignment: .trailing)
                    .multilineTextAlignment(.trailing)
                    .onChange(of: caratsText) { _, val in
                        guard !isSyncing else { return }
                        item.carats = Double(val) ?? 0
                        item.amount = item.rate * Decimal(item.carats)
                        onUpdate()
                    }
            }

            // Rate
            TextField("0.00", text: $rateText)
                .textFieldStyle(.plain)
                .frame(width: w(4), alignment: .trailing)
                .multilineTextAlignment(.trailing)
                .onChange(of: rateText) { _, val in
                    guard !isSyncing else { return }
                    item.rate = Decimal(string: val) ?? 0
                    if item.kind == .service {
                        item.amount = item.rate
                    } else {
                        item.amount = item.rate * Decimal(item.carats)
                    }
                    onUpdate()
                }

            // Amount (read-only)
            Text(item.amount.asCurrency)
                .font(AppTypography.mono)
                .foregroundStyle(AppColors.ink)
                .frame(width: w(5), alignment: .trailing)

            // Delete button
            if let onDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.inkSubtle)
                }
                .buttonStyle(.plain)
                .frame(width: 28)
            }
        }
        .onAppear { syncFromModel() }
    }

    private func syncFromModel() {
        isSyncing = true
        descriptionText = item.itemDescription
        caratsText = item.carats == 0 ? "" : String(format: "%.2f", item.carats)
        rateText = item.rate == 0 ? "" : "\(item.rate)"
        isSyncing = false
    }
}
