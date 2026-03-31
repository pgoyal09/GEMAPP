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
                RoundedRectangle(cornerRadius: AppCornerRadius.large, style: .continuous)
                    .fill(tint.opacity(configuration.isPressed ? 0.12 : 0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppCornerRadius.large, style: .continuous)
                    .strokeBorder(tint.opacity(0.3), lineWidth: 1)
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
