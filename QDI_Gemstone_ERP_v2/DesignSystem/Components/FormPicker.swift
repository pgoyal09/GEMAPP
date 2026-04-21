import SwiftUI

/// Reusable labeled picker with consistent glass styling matching FormField.
/// Uses generic Content instead of AnyView to preserve SwiftUI diffing.
struct FormPicker<SelectionValue: Hashable, Content: View>: View {
    let label: String
    @Binding var selection: SelectionValue
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.compact) {
            Text(label)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.inkSubtle)
            Picker(label, selection: $selection) {
                content()
            }
            .labelsHidden()
            .glassField()
            .accessibilityLabel(label)
        }
    }
}
