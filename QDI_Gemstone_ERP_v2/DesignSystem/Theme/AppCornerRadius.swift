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

    // MARK: - Legacy aliases (deprecated — use semantic names above)
    @available(*, deprecated, renamed: "field", message: "Use AppCornerRadius.field (3pt) instead")
    static let medium: CGFloat = field
    @available(*, deprecated, renamed: "card", message: "Use AppCornerRadius.card (4pt) instead")
    static let large: CGFloat = card
}
