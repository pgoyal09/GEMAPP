import SwiftUI

enum AppSpacing {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 6
    static let s: CGFloat = 10
    static let m: CGFloat = 14
    static let l: CGFloat = 20
    static let xl: CGFloat = 28
    static let xxl: CGFloat = 36

    // MARK: - Semantic Tokens (standard spacing scale)
    /// 4pt — tightest standard spacing
    static let tight: CGFloat = 4
    /// 8pt — standard small spacing
    static let compact: CGFloat = 8
    /// 12pt — standard medium spacing
    static let cozy: CGFloat = 12
    /// 16pt — standard large spacing
    static let standard: CGFloat = 16
    /// 24pt — section spacing
    static let section: CGFloat = 24
    /// 32pt — large section spacing
    static let region: CGFloat = 32
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
