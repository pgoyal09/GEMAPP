import SwiftUI

/// Glass-morphism card container used throughout the app.
/// Falls back to solid background when reduce-transparency is enabled.
struct GlassCard<Content: View>: View {
    var padding: CGFloat = AppSpacing.hero
    var cornerRadius: CGFloat = AppCornerRadius.large
    @ViewBuilder var content: Content

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(reduceTransparency ? AppColors.cardElevated : AppColors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(AppColors.cardStroke, lineWidth: 1)
                    )
            )
            .accessibilityElement(children: .contain)
    }
}

/// Surface card with optional accent border.
struct SurfaceCard<Content: View>: View {
    var padding: CGFloat = AppSpacing.hero
    var accent: Color? = nil
    @ViewBuilder var content: Content

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.section) {
            content
        }
        .padding(padding)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: AppCornerRadius.large, style: .continuous)
                    .fill(reduceTransparency ? AppColors.cardElevated : AppColors.cardBackground)
                RoundedRectangle(cornerRadius: AppCornerRadius.large, style: .continuous)
                    .strokeBorder(AppColors.cardStroke, lineWidth: 1)
                if let accent {
                    RoundedRectangle(cornerRadius: AppCornerRadius.large, style: .continuous)
                        .stroke(accent.opacity(0.20), lineWidth: 1)
                }
            }
        )
    }
}
