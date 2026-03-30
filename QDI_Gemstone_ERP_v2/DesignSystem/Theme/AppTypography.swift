import SwiftUI

enum AppTypography {
    static let title      = Font.system(.largeTitle, weight: .semibold)
    static let heading    = Font.system(.headline, weight: .semibold)
    static let subheading = Font.system(.subheadline, weight: .medium)
    static let body       = Font.system(.body, weight: .regular)
    static let caption    = Font.system(.caption, weight: .medium)
    static let mono       = Font.system(.footnote, design: .monospaced).weight(.medium)
    static let sectionLabel = Font.system(.caption2, weight: .medium)
    static let largeValue = Font.system(.title, weight: .semibold)
    static let smallValue = Font.system(.footnote, weight: .medium)
}
