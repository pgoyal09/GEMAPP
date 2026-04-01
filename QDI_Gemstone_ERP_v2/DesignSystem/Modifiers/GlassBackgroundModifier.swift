import SwiftUI

struct GlassBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background(AppColors.background)
    }
}

extension View {
    func appBackground() -> some View {
        modifier(GlassBackgroundModifier())
    }
}
