import SwiftUI

enum AppSpacing {
    /// 2pt — tight row/column gaps in dense tables
    static let tight: CGFloat = 2
    /// 4pt — compact padding, icon gaps
    static let compact: CGFloat = 4
    /// 6pt — small gaps between related elements (filter pills, badges)
    static let small: CGFloat = 6
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

    /// 4pt — gap between table columns (same as compact, semantic alias)
    static let tableColumnGap: CGFloat = 4
}

enum AppShadows {
    static let outer = (color: AppColors.softShadow, radius: CGFloat(16), x: CGFloat(0), y: CGFloat(10))

    static func subtle(_ content: some View) -> some View {
        content.shadow(color: Color.black.opacity(AppOpacity.muted), radius: 4, y: 2)
    }
    static func standard(_ content: some View) -> some View {
        content.shadow(color: Color.black.opacity(AppOpacity.muted), radius: 8, y: 4)
    }
    static func elevated(_ content: some View) -> some View {
        content.shadow(color: Color.black.opacity(AppOpacity.medium), radius: 16, y: 8)
    }
}

extension View {
    func shadowSubtle() -> some View {
        shadow(color: Color.black.opacity(AppOpacity.muted), radius: 4, y: 2)
    }
    func shadowStandard() -> some View {
        shadow(color: Color.black.opacity(AppOpacity.muted), radius: 8, y: 4)
    }
    func shadowElevated() -> some View {
        shadow(color: Color.black.opacity(AppOpacity.medium), radius: 16, y: 8)
    }
}
