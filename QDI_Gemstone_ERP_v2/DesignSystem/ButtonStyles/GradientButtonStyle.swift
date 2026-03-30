import SwiftUI

/// Primary action button with gradient background.
struct GradientButtonStyle: ButtonStyle {
    var gradient: LinearGradient = AppColors.primaryGradient

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.body.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, AppSpacing.l)
            .padding(.vertical, AppSpacing.s)
            .background(gradient)
            .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.m, style: .continuous))
            .opacity(configuration.isPressed ? 0.8 : 1)
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
