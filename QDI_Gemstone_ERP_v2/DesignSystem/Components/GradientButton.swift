import SwiftUI

struct GradientButton: View {
    let title: String
    var icon: String? = nil
    var gradient: LinearGradient = AppColors.primaryGradient
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(AppTypography.smallValue)
                }
                Text(title)
                    .font(AppTypography.smallValue)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, AppSpacing.standard)
            .padding(.vertical, AppSpacing.compact)
            .background(gradient, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: AppColors.primary.opacity(0.20), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}
