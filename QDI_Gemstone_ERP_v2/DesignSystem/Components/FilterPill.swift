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
                .padding(.horizontal, AppSpacing.standard)
                .padding(.vertical, AppSpacing.xs)
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
                .overlay {
                    if isActive, let ns = animationNamespace {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
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
