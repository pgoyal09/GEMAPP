import SwiftUI

// MARK: - Colors (Budget-Pro pastel theme)

enum AppColors {
    static let primary = Color(red: 0.68, green: 0.78, blue: 0.92)
    static let accent = Color(red: 0.95, green: 0.65, blue: 0.65)
    static let background = Color(red: 0.98, green: 0.98, blue: 0.99)
    static let cardBackground = Color(.controlBackgroundColor)
    static let cardStroke = Color.primary.opacity(0.12)
}

// MARK: - Spacing

enum AppSpacing {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
}

// MARK: - Corner Radius

enum AppCornerRadius {
    static let s: CGFloat = 6
    static let m: CGFloat = 10
    static let l: CGFloat = 12
}

// MARK: - Shadows (optional, for elevation)

enum AppShadows {
    static let subtle = Color.black.opacity(0.06)
}

// MARK: - Inspector Panel (QuickBooks-style right-side detail)

enum InspectorWidth {
    static let min: CGFloat = 320
    static let ideal: CGFloat = 380
    static let max: CGFloat = 480
}
