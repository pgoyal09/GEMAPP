import SwiftUI

enum AppSpacing {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 6
    static let s: CGFloat = 10
    static let m: CGFloat = 14
    static let l: CGFloat = 20
    static let xl: CGFloat = 28
    static let xxl: CGFloat = 36
}

enum AppCornerRadius {
    static let s: CGFloat = 10
    static let m: CGFloat = 16
    static let l: CGFloat = 22
    static let xl: CGFloat = 30
}

enum AppShadows {
    static let outer = (color: AppColors.softShadow, radius: CGFloat(16), x: CGFloat(0), y: CGFloat(10))
}
