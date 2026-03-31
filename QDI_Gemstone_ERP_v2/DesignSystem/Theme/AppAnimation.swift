import SwiftUI

enum AppAnimation {
    static let fast = Animation.easeInOut(duration: 0.15)
    static let standard = Animation.easeInOut(duration: 0.25)
    static let slow = Animation.easeInOut(duration: 0.35)
    static let spring = Animation.spring(response: 0.4, dampingFraction: 0.8)
    static let sheetSpring = Animation.spring(response: 0.35, dampingFraction: 0.85)

    /// Continuous shimmer animation for loading placeholders.
    static let shimmer = Animation.easeInOut(duration: 1.2).repeatForever(autoreverses: false)
}

extension View {
    /// Animates only when the user hasn't enabled Reduce Motion.
    func animateIfAllowed<V: Equatable>(_ animation: Animation?, value: V, reduceMotion: Bool) -> some View {
        self.animation(reduceMotion ? nil : animation, value: value)
    }
}
