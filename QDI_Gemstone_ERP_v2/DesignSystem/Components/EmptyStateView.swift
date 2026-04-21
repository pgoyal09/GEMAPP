import SwiftUI

/// Consistent empty state view used across all list views.
struct EmptyStateView: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: AppSpacing.section) {
            Image(systemName: icon)
                .font(AppTypography.title)
                .foregroundStyle(AppColors.inkSubtle)
            Text(title)
                .font(AppTypography.heading)
                .foregroundStyle(AppColors.inkMuted)
            if let subtitle {
                Text(subtitle)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.inkSubtle)
            }
            if let actionLabel, let action {
                Button(actionLabel, action: action)
                    .buttonStyle(.gradient)
                    .padding(.top, AppSpacing.standard)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(AppSpacing.page)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title)\(subtitle.map { ". \($0)" } ?? "")")
    }
}
