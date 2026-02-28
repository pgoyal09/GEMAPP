import SwiftUI

/// Shared column widths and layout for line item tables (Memo + Invoice).
/// Use consistently in headers and rows so columns align.
enum LineItemColumnLayout {
    static let sku: CGFloat = 120
    static let descriptionMin: CGFloat = 360
    static let carats: CGFloat = 110
    static let rate: CGFloat = 130
    static let amount: CGFloat = 140
    static let status: CGFloat = 100
    static let check: CGFloat = 30
}
