import SwiftUI

/// Reusable labeled picker with consistent glass styling matching FormField.
struct FormPicker<SelectionValue: Hashable>: View {
    let label: String
    @Binding var selection: SelectionValue
    let content: () -> AnyView

    init<C: View>(label: String, selection: Binding<SelectionValue>, @ViewBuilder content: @escaping () -> C) {
        self.label = label
        self._selection = selection
        self.content = { AnyView(content()) }
    }

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
