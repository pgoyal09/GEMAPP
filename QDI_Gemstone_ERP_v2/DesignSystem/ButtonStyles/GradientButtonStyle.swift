import SwiftUI

/// Primary action button with gradient background.
struct GradientButtonStyle: ButtonStyle {
    var gradient: LinearGradient = AppColors.primaryGradient

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.body.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, AppSpacing.hero)
            .padding(.vertical, AppSpacing.comfortable)
            .background(gradient)
            .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.medium, style: .continuous))
            .shadow(color: AppColors.primary.opacity(configuration.isPressed ? 0.08 : 0.20), radius: configuration.isPressed ? 4 : 8, y: configuration.isPressed ? 2 : 4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == GradientButtonStyle {
    static var gradient: GradientButtonStyle { GradientButtonStyle() }
    static func gradient(_ gradient: LinearGradient) -> GradientButtonStyle {
        GradientButtonStyle(gradient: gradient)
    }
}
