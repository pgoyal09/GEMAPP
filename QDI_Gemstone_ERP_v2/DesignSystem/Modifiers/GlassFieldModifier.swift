import SwiftUI

struct GlassFieldModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isFocused: Bool

    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .padding(AppSpacing.comfortable)
            .focused($isFocused)
            .background(
                RoundedRectangle(cornerRadius: AppCornerRadius.field, style: .continuous)
                    .fill(AppColors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppCornerRadius.field, style: .continuous)
                    .strokeBorder(
                        isFocused ? AppColors.primary : AppColors.cardStroke,
                        lineWidth: isFocused ? 1.5 : 1
                    )
            )
            .animation(reduceMotion ? nil : AppAnimation.fast, value: isFocused)
    }
}

extension View {
    func glassField() -> some View {
        modifier(GlassFieldModifier())
    }
}
