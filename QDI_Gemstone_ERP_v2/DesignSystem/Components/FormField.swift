import SwiftUI

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
                .textFieldStyle(.plain)
                .font(AppTypography.body)
                .padding(.horizontal, AppSpacing.standard)
                .frame(height: 28)
                .background(
                    RoundedRectangle(cornerRadius: AppCornerRadius.field, style: .continuous)
                        .fill(AppColors.cardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppCornerRadius.field, style: .continuous)
                        .strokeBorder(error != nil ? AppColors.danger : AppColors.cardStroke, lineWidth: 1)
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
