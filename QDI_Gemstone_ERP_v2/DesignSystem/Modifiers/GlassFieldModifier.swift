import SwiftUI

/// Applies glass-morphism styling to text fields and pickers.
struct GlassFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .padding(AppSpacing.s)
            .background(
                RoundedRectangle(cornerRadius: AppCornerRadius.s, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppCornerRadius.s, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
            )
    }
}

extension View {
    func glassField() -> some View {
        modifier(GlassFieldModifier())
    }
}
