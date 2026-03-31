import SwiftUI
import SwiftData

/// Sheet for applying bulk edits to multiple selected stones.
struct BulkEditSheet: View {
    enum Mode: Identifiable {
        case updateStatus
        case updatePrice
        case moveToLot

        var id: Int {
            switch self {
            case .updateStatus: return 0
            case .updatePrice: return 1
            case .moveToLot: return 2
            }
        }

        var title: String {
            switch self {
            case .updateStatus: return "Update Status"
            case .updatePrice: return "Update Price"
            case .moveToLot: return "Move to Lot"
            }
        }
    }

    let mode: Mode
    let stoneCount: Int
    let onApply: (BulkEditAction) -> Void

    @Environment(\.dismiss) private var dismiss

    // Status
    @State private var selectedStatus: GemstoneStatus = .available

    // Price
    @State private var priceField: PriceField = .sellPrice
    @State private var priceText: String = ""

    // Lot
    @State private var lotSKU: String = ""

    enum PriceField: String, CaseIterable {
        case costPrice = "Cost Price"
        case sellPrice = "Sell Price"
    }

    var body: some View {
        VStack(spacing: AppSpacing.section) {
            Text(mode.title)
                .font(AppTypography.title)
                .foregroundStyle(AppColors.ink)

            Text("Applying to \(stoneCount) stone\(stoneCount == 1 ? "" : "s")")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.inkMuted)

            Divider()

            switch mode {
            case .updateStatus:
                statusContent
            case .updatePrice:
                priceContent
            case .moveToLot:
                lotContent
            }

            Spacer()

            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.outline)
                    .keyboardShortcut(.cancelAction)
                    .keyboardShortcut(.escape, modifiers: [])
                Spacer()
                Button("Apply") { applyAction() }
                    .buttonStyle(.gradient)
                    .disabled(!canApply)
                    .keyboardShortcut(.defaultAction)
                    .accessibilityHint("Double tap to update \(mode.title.lowercased()) of \(stoneCount) selected stones")
            }
        }
        .padding(AppSpacing.hero)
        .frame(width: 360, height: 280)
        .appBackground()
    }

    // MARK: - Status

    private var statusContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.comfortable) {
            Text("New Status").font(AppTypography.caption).foregroundStyle(AppColors.inkSubtle)
            Picker("Status", selection: $selectedStatus) {
                ForEach(GemstoneStatus.allCases, id: \.self) { status in
                    Text(status.rawValue).tag(status)
                }
            }
            .labelsHidden()
        }
    }

    // MARK: - Price

    private var priceContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.comfortable) {
            Picker("Field", selection: $priceField) {
                ForEach(PriceField.allCases, id: \.self) { f in
                    Text(f.rawValue).tag(f)
                }
            }
            .labelsHidden()
            FormField(label: "New Price ($/ct)", text: $priceText)
        }
    }

    // MARK: - Lot

    private var lotContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.comfortable) {
            FormField(label: "Lot SKU", text: $lotSKU)
            Text("Stones will be moved to the lot grouping.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.inkMuted)
        }
    }

    // MARK: - Logic

    private var canApply: Bool {
        switch mode {
        case .updateStatus: return true
        case .updatePrice: return Decimal(string: priceText) != nil && (Decimal(string: priceText) ?? -1) >= 0
        case .moveToLot: return !lotSKU.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    private func applyAction() {
        switch mode {
        case .updateStatus:
            onApply(.setStatus(selectedStatus))
        case .updatePrice:
            if let price = Decimal(string: priceText) {
                onApply(.setPrice(field: priceField, value: price))
            }
        case .moveToLot:
            onApply(.moveToLot(sku: lotSKU.trimmingCharacters(in: .whitespaces)))
        }
        dismiss()
    }
}

/// Actions that can be applied in bulk.
enum BulkEditAction {
    case setStatus(GemstoneStatus)
    case setPrice(field: BulkEditSheet.PriceField, value: Decimal)
    case moveToLot(sku: String)
}
