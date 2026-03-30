import SwiftUI

/// Applies glass card styling to table containers with header separator.
struct GlassTableModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: AppCornerRadius.l, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(0.6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppCornerRadius.l, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.l, style: .continuous))
    }
}

extension View {
    func glassTable() -> some View {
        modifier(GlassTableModifier())
    }
}
