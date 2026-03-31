import SwiftUI

/// Reusable label + text field with consistent styling, optional error state, and accessibility.
struct FormField: View {
    let label: String
    @Binding var text: String
    var error: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.compact) {
            Text(label)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.inkSubtle)
            TextField(label, text: $text)
                .glassField()
                .overlay(
                    RoundedRectangle(cornerRadius: AppCornerRadius.medium, style: .continuous)
                        .strokeBorder(error != nil ? AppColors.danger : Color.clear, lineWidth: 1.5)
                )
                .accessibilityLabel(label)
            if let error {
                Text(error)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.danger)
                    .accessibilityLabel("\(label) error: \(error)")
            }
        }
    }
}
