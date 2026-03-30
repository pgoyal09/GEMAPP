import SwiftUI

enum AppAnimation {
    static let fast = Animation.easeInOut(duration: 0.15)
    static let standard = Animation.easeInOut(duration: 0.2)
    static let slow = Animation.easeInOut(duration: 0.35)
    static let spring = Animation.spring(response: 0.35, dampingFraction: 0.75)
}
