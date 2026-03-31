import SwiftUI

/// Secondary action button with glass outline.
struct OutlineButtonStyle: ButtonStyle {
    var tint: Color = AppColors.primary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.body.weight(.medium))
            .foregroundStyle(tint)
            .padding(.horizontal, AppSpacing.hero)
            .padding(.vertical, AppSpacing.comfortable)
            .background(
                RoundedRectangle(cornerRadius: AppCornerRadius.medium, style: .continuous)
                    .fill(tint.opacity(configuration.isPressed ? 0.12 : AppOpacity.subtle))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppCornerRadius.medium, style: .continuous)
                    .strokeBorder(tint.opacity(AppOpacity.medium), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == OutlineButtonStyle {
    static var outline: OutlineButtonStyle { OutlineButtonStyle() }
    static func outline(_ tint: Color) -> OutlineButtonStyle {
        OutlineButtonStyle(tint: tint)
    }
}
