import SwiftUI

struct FilterPill: View {
    let title: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppTypography.caption)
                .foregroundStyle(isActive ? AppColors.primary : AppColors.inkSubtle)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isActive ? AppColors.primary.opacity(0.20) : Color.white.opacity(0.03))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(
                                    isActive ? AppColors.primary.opacity(0.20) : Color.white.opacity(0.06),
                                    lineWidth: 1
                                )
                        )
                )
        }
        .buttonStyle(.plain)
    }
}
