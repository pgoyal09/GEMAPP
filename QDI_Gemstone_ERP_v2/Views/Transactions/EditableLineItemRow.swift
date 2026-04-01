import SwiftUI
import SwiftData

struct EditableLineItemRow: View {
    @Bindable var item: LineItem
    @Environment(\.modelContext) private var modelContext
    var onUpdate: () -> Void = {}

    @State private var descriptionText: String = ""
    @State private var caratsText: String = ""
    @State private var rateText: String = ""
    @State private var isSyncing = false

    var body: some View {
        HStack(spacing: AppSpacing.standard) {
            // SKU
            Text(item.displaySku)
                .font(AppTypography.mono)
                .foregroundStyle(AppColors.inkMuted)
                .frame(width: TableColumn.sku, alignment: .leading)

            // Stone Type
            if item.kind == .brokered {
                Picker("", selection: $item.brokeredStoneType) {
                    Text("—").tag("")
                    ForEach(StoneType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type.rawValue)
                    }
                }
                .labelsHidden()
                .frame(width: TableColumn.type)
            } else {
                Text(item.stoneTypeDisplay)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.inkMuted)
                    .frame(width: TableColumn.type, alignment: .leading)
            }

            // Description
            TextField("Description", text: $descriptionText)
                .glassField()
                .frame(width: TableColumn.description)
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
                    .frame(width: TableColumn.carat, alignment: .trailing)
            } else {
                TextField("0.00", text: $caratsText)
                    .glassField()
                    .frame(width: TableColumn.carat)
                    .onChange(of: caratsText) { _, val in
                        guard !isSyncing else { return }
                        item.carats = Double(val) ?? 0
                        item.amount = item.rate * Decimal(item.carats)
                        onUpdate()
                    }
            }

            // Rate
            TextField("0.00", text: $rateText)
                .glassField()
                .frame(width: TableColumn.price)
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
                .frame(width: TableColumn.price, alignment: .trailing)
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
