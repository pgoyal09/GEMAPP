import SwiftUI

/// Consistent empty state view used across all list views.
struct EmptyStateView: View {
    let icon: String
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(spacing: AppSpacing.m) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(AppColors.inkSubtle)
            Text(title)
                .font(AppTypography.heading)
                .foregroundStyle(AppColors.inkMuted)
            if let subtitle {
                Text(subtitle)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.inkSubtle)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(AppSpacing.xxl)
    }
}
