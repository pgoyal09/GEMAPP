import SwiftUI

struct GlassTableModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                    .fill(AppColors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                    .strokeBorder(AppColors.cardStroke, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous))
    }
}

extension View {
    func glassTable() -> some View {
        modifier(GlassTableModifier())
    }
}
