import SwiftUI

struct GlassCard<Content: View>: View {
    var padding: CGFloat = AppSpacing.hero
    var cornerRadius: CGFloat = AppCornerRadius.card
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(AppColors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(AppColors.cardStroke, lineWidth: 1)
                    )
            )
            .accessibilityElement(children: .contain)
    }
}

struct SurfaceCard<Content: View>: View {
    var padding: CGFloat = AppSpacing.hero
    var accent: Color? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.section) {
            content
        }
        .padding(padding)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                    .fill(AppColors.cardBackground)
                RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                    .strokeBorder(AppColors.cardStroke, lineWidth: 1)
                if let accent {
                    RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                        .stroke(accent.opacity(AppOpacity.muted), lineWidth: 1)
                }
            }
        )
        .accessibilityElement(children: .contain)
    }
}
