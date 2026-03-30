import SwiftUI

/// Applies the app's dark gradient background to any view.
struct GlassBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppColors.shellGradient)
    }
}

extension View {
    func appBackground() -> some View {
        modifier(GlassBackgroundModifier())
    }
}
