import SwiftUI

struct RapNetFieldsView: View {

    private struct FieldEntry: Identifiable {
        let id = UUID()
        let name: String
        let defaultValue: String?

        var statusText: String {
            if let d = defaultValue { return d }
            return "Required"
        }

        var isRequired: Bool { defaultValue == nil }
    }

    private let diamondFields: [FieldEntry] = [
        .init(name: "Stock#", defaultValue: nil),
        .init(name: "Shape", defaultValue: nil),
        .init(name: "Carat", defaultValue: nil),
        .init(name: "Color", defaultValue: nil),
        .init(name: "Clarity", defaultValue: nil),
        .init(name: "Cut", defaultValue: nil),
        .init(name: "Polish", defaultValue: nil),
        .init(name: "Symmetry", defaultValue: nil),
        .init(name: "Fluorescence", defaultValue: "None"),
        .init(name: "Lab", defaultValue: nil),
        .init(name: "Cert#", defaultValue: nil),
        .init(name: "Price/ct", defaultValue: nil),
        .init(name: "Total Price", defaultValue: nil),
        .init(name: "Measurements (L×W×D)", defaultValue: nil),
        .init(name: "Table%", defaultValue: nil),
        .init(name: "Depth%", defaultValue: nil),
        .init(name: "Girdle", defaultValue: "N/A"),
        .init(name: "Culet", defaultValue: "None"),
    ]

    private let gemstoneFields: [FieldEntry] = [
        .init(name: "Stock#", defaultValue: nil),
        .init(name: "Shape", defaultValue: nil),
        .init(name: "Carat", defaultValue: nil),
        .init(name: "Color", defaultValue: nil),
        .init(name: "Variety", defaultValue: nil),
        .init(name: "Treatment", defaultValue: "None/Untreated"),
        .init(name: "Origin", defaultValue: "Not Specified"),
        .init(name: "Lab", defaultValue: nil),
        .init(name: "Cert#", defaultValue: nil),
        .init(name: "Price/ct", defaultValue: nil),
        .init(name: "Total Price", defaultValue: nil),
        .init(name: "Measurements", defaultValue: nil),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.hero) {
                SectionHeader(title: "Diamond Upload Fields")
                fieldTable(diamondFields)

                SectionHeader(title: "Gemstone Upload Fields")
                fieldTable(gemstoneFields)
            }
            .padding(AppSpacing.hero)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appBackground()
        .navigationTitle("RapNet Upload Fields Reference")
        .accessibilityIdentifier("RapNetFieldsView")
    }

    @ViewBuilder
    private func fieldTable(_ fields: [FieldEntry]) -> some View {
        VStack(spacing: 0) {
            // Header row
            HStack(spacing: 0) {
                Text("Field")
                    .font(AppTypography.caption.weight(.semibold))
                    .foregroundStyle(AppColors.inkSubtle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Default / Status")
                    .font(AppTypography.caption.weight(.semibold))
                    .foregroundStyle(AppColors.inkSubtle)
                    .frame(width: 160, alignment: .leading)
            }
            .padding(.horizontal, AppSpacing.comfortable)
            .padding(.vertical, AppSpacing.standard)

            Divider().background(AppColors.cardStroke)

            ForEach(fields) { field in
                HStack(spacing: 0) {
                    Text(field.name)
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(field.statusText)
                        .font(AppTypography.mono)
                        .foregroundStyle(field.isRequired ? AppColors.inkMuted : AppColors.success)
                        .frame(width: 160, alignment: .leading)
                }
                .padding(.horizontal, AppSpacing.comfortable)
                .padding(.vertical, AppSpacing.standard)

                Divider().background(AppColors.cardStroke.opacity(0.5))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                .fill(AppColors.panelBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                        .strokeBorder(AppColors.cardStroke, lineWidth: 1)
                )
        )
    }
}
