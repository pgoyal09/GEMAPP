import SwiftUI

/// Applies glass card styling to table containers with header separator.
/// Falls back to solid background when reduce-transparency is enabled.
struct GlassTableModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        content
            .background(tableBackground)
            .overlay(
                RoundedRectangle(cornerRadius: AppCornerRadius.l, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.l, style: .continuous))
    }

    @ViewBuilder
    private var tableBackground: some View {
        if reduceTransparency {
            RoundedRectangle(cornerRadius: AppCornerRadius.l, style: .continuous)
                .fill(AppColors.cardBackground)
        } else {
            RoundedRectangle(cornerRadius: AppCornerRadius.l, style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(0.6)
        }
    }
}

extension View {
    func glassTable() -> some View {
        modifier(GlassTableModifier())
    }
}
