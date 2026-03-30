import SwiftUI

struct StoneTypeBadge: View {
    let type: String

    var body: some View {
        Text(type)
            .font(AppTypography.sectionLabel)
            .foregroundStyle(AppColors.stoneColor(for: type))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(AppColors.stoneColor(for: type).opacity(0.15))
            )
    }
}
