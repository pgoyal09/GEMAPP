import SwiftUI

struct FilterPill: View {
    let title: String
    let isActive: Bool
    let action: () -> Void
    var animationNamespace: Namespace.ID? = nil

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppTypography.caption)
                .foregroundStyle(isActive ? AppColors.primary : AppColors.inkSubtle)
                .padding(.horizontal, AppSpacing.section)
                .padding(.vertical, AppSpacing.standard)
                .background(
                    RoundedRectangle(cornerRadius: AppCornerRadius.small, style: .continuous)
                        .fill(isActive ? AppColors.primary.opacity(0.20) : Color.white.opacity(AppOpacity.faint))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppCornerRadius.small, style: .continuous)
                                .strokeBorder(
                                    isActive ? AppColors.primary.opacity(0.20) : Color.white.opacity(0.06),
                                    lineWidth: 1
                                )
                        )
                )
                .overlay {
                    if isActive, let ns = animationNamespace {
                        RoundedRectangle(cornerRadius: AppCornerRadius.small, style: .continuous)
                            .strokeBorder(AppColors.primary.opacity(0.5), lineWidth: 2)
                            .matchedGeometryEffect(id: "filterPillIndicator", in: ns)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) filter")
        .accessibilityValue(isActive ? "Active" : "Inactive")
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}
