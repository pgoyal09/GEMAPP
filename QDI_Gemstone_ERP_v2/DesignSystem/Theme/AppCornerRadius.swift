import SwiftUI

enum AppCornerRadius {
    /// 3pt — text fields, inputs
    static let field: CGFloat = 3
    /// 4pt — cards, panels
    static let card: CGFloat = 4
    /// 6pt — modals, sheets
    static let modal: CGFloat = 6
    /// 3pt — buttons
    static let button: CGFloat = 3
    /// 3pt — alias for field
    static let small: CGFloat = 3
    /// 999pt — capsule / pill shape
    static let pill: CGFloat = 999

    // MARK: - Legacy aliases (map to new values)
    static let medium: CGFloat = field   // was 12, now 3
    static let large: CGFloat = card     // was 16, now 4
}
