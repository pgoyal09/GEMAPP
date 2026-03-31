import SwiftUI

struct StoneTypeBadge: View {
    let type: String

    var body: some View {
        Text(type)
            .font(AppTypography.sectionLabel)
            .foregroundStyle(AppColors.stoneColor(for: type))
            .padding(.horizontal, AppSpacing.standard)
            .padding(.vertical, AppSpacing.compact)
            .background(
                RoundedRectangle(cornerRadius: AppCornerRadius.small, style: .continuous)
                    .fill(AppColors.stoneColor(for: type).opacity(0.15))
            )
            .accessibilityLabel("Stone type: \(type)")
    }
}
