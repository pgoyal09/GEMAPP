import SwiftUI

struct StoneTypeBadge: View {
    let type: String

    var body: some View {
        Text(type)
            .font(AppTypography.sectionLabel)
            .foregroundStyle(AppColors.stoneColor(for: type))
            .padding(.horizontal, AppSpacing.compact)
            .padding(.vertical, AppSpacing.xxs)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(AppColors.stoneColor(for: type).opacity(0.15))
            )
            .accessibilityLabel("Stone type: \(type)")
    }
}
