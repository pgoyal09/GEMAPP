import SwiftUI

enum AppAnimation {
    static let fast = Animation.easeInOut(duration: 0.15)
    static let standard = Animation.easeInOut(duration: 0.25)
    static let slow = Animation.easeInOut(duration: 0.35)
    static let spring = Animation.spring(response: 0.4, dampingFraction: 0.8)
    static let sheetSpring = Animation.spring(response: 0.35, dampingFraction: 0.85)

    /// Continuous shimmer animation for loading placeholders (2s per cycle — gentle, not frantic).
    static let shimmer = Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: false)

    /// Brief scale pulse for value changes.
    static let pulse = Animation.spring(response: 0.3, dampingFraction: 0.5)

    /// Stagger delay for list row appearance (capped at 15 rows).
    static func staggerDelay(index: Int) -> Double {
        Double(min(index, 15)) * 0.03
    }
}

extension View {
    /// Animates only when the user hasn't enabled Reduce Motion.
    func animateIfAllowed<V: Equatable>(_ animation: Animation?, value: V, reduceMotion: Bool) -> some View {
        self.animation(reduceMotion ? nil : animation, value: value)
    }
}

/// Modifier that fades in a row with stagger delay based on index.
struct StaggeredRowModifier: ViewModifier {
    let index: Int
    let reduceMotion: Bool
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 8)
            .onAppear {
                if reduceMotion {
                    appeared = true
                } else {
                    withAnimation(AppAnimation.standard.delay(AppAnimation.staggerDelay(index: index))) {
                        appeared = true
                    }
                }
            }
    }
}

extension View {
    func staggeredRow(index: Int, reduceMotion: Bool) -> some View {
        modifier(StaggeredRowModifier(index: index, reduceMotion: reduceMotion))
    }
}
