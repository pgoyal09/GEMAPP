import SwiftUI

enum AppSpacing {
    /// 4pt — compact padding, icon gaps
    static let compact: CGFloat = 4
    /// 8pt — standard small spacing
    static let standard: CGFloat = 8
    /// 12pt — comfortable medium spacing
    static let comfortable: CGFloat = 12
    /// 16pt — section-level internal padding
    static let section: CGFloat = 16
    /// 24pt — hero / card spacing
    static let hero: CGFloat = 24
    /// 32pt — page-level spacing
    static let page: CGFloat = 32
}

enum AppCornerRadius {
    /// 8pt — small elements (badges, pills)
    static let small: CGFloat = 8
    /// 12pt — medium elements (fields, cards)
    static let medium: CGFloat = 12
    /// 16pt — large containers
    static let large: CGFloat = 16
    /// 999pt — capsule / pill shape
    static let pill: CGFloat = 999
}

enum AppShadows {
    static let outer = (color: AppColors.softShadow, radius: CGFloat(16), x: CGFloat(0), y: CGFloat(10))
}
