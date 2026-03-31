import SwiftUI

/// Applies glass-morphism styling to text fields and pickers with focus ring.
struct GlassFieldModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isFocused: Bool

    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .padding(AppSpacing.comfortable)
            .focused($isFocused)
            .background(
                RoundedRectangle(cornerRadius: AppCornerRadius.medium, style: .continuous)
                    .fill(Color.white.opacity(AppOpacity.subtle))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppCornerRadius.medium, style: .continuous)
                    .strokeBorder(
                        isFocused ? AppColors.primary : Color.white.opacity(0.1),
                        lineWidth: isFocused ? 1.5 : 1
                    )
            )
            .shadow(color: isFocused ? AppColors.primary.opacity(AppOpacity.medium) : .clear, radius: 4, y: 0)
            .animation(reduceMotion ? nil : AppAnimation.fast, value: isFocused)
    }
}

extension View {
    func glassField() -> some View {
        modifier(GlassFieldModifier())
    }
}
