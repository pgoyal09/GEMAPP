import SwiftUI

enum AppAnimation {
    static let fast = Animation.easeInOut(duration: 0.15)
    static let standard = Animation.easeInOut(duration: 0.25)
    static let slow = Animation.easeInOut(duration: 0.35)
    static let spring = Animation.spring(response: 0.4, dampingFraction: 0.8)
    static let sheetSpring = Animation.spring(response: 0.35, dampingFraction: 0.85)
    static let shimmer = Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: false)
    static let pulse = Animation.spring(response: 0.3, dampingFraction: 0.5)

    static func staggerDelay(index: Int) -> Double {
        Double(min(index, 15)) * 0.03
    }
}

extension View {
    func animateIfAllowed<V: Equatable>(_ animation: Animation?, value: V, reduceMotion: Bool) -> some View {
        self.animation(reduceMotion ? nil : animation, value: value)
    }
}

struct StaggeredRowModifier: ViewModifier {
    let index: Int
    let reduceMotion: Bool
    /// Cap: rows beyond this index appear instantly (no @State animation overhead)
    private static let maxStaggerIndex = 15
    @State private var appeared = false

    func body(content: Content) -> some View {
        if reduceMotion || index >= Self.maxStaggerIndex {
            content
        } else {
            content
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 8)
                .onAppear {
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
