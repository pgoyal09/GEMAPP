import SwiftUI

/// Applies the app's dark gradient background to any view.
/// When reduce-transparency is enabled, uses a solid background instead of gradient.
struct GlassBackgroundModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(AppColors.background)
        } else {
            content.background(AppColors.shellGradient)
        }
    }
}

extension View {
    func appBackground() -> some View {
        modifier(GlassBackgroundModifier())
    }
}
