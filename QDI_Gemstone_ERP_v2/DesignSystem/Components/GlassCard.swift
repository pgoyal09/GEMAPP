import SwiftUI

/// Glass-morphism card container used throughout the app.
struct GlassCard<Content: View>: View {
    var padding: CGFloat = AppSpacing.l
    var cornerRadius: CGFloat = AppCornerRadius.m
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
    }
}

/// Surface card with optional accent border.
struct SurfaceCard<Content: View>: View {
    var padding: CGFloat = AppSpacing.l
    var accent: Color? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            content
        }
        .padding(padding)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: AppCornerRadius.m, style: .continuous)
                    .fill(AppColors.cardBackground)
                RoundedRectangle(cornerRadius: AppCornerRadius.m, style: .continuous)
                    .strokeBorder(AppColors.cardStroke, lineWidth: 1)
                if let accent {
                    RoundedRectangle(cornerRadius: AppCornerRadius.m, style: .continuous)
                        .stroke(accent.opacity(0.20), lineWidth: 1)
                }
            }
        )
    }
}
