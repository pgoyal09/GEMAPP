import SwiftUI

enum AppTypography {
    private static var sizeOffset: CGFloat {
        switch UserDefaults.standard.string(forKey: "displayFontSize") ?? "Small" {
        case "Medium": return 2
        case "Large": return 4
        default: return 0
        }
    }

    static var title: Font      { Font.system(size: 28 + sizeOffset, weight: .semibold) }
    static var heading: Font    { Font.system(size: 15 + sizeOffset, weight: .semibold) }
    static var subheading: Font { Font.system(size: 13 + sizeOffset, weight: .medium) }
    static var body: Font       { Font.system(size: 13 + sizeOffset, weight: .regular) }
    static var caption: Font    { Font.system(size: 11 + sizeOffset, weight: .medium) }
    static var mono: Font       { Font.system(size: 12 + sizeOffset, design: .monospaced).weight(.medium) }
    static var sectionLabel: Font { Font.system(size: 10 + sizeOffset, weight: .medium) }
    static var largeValue: Font { Font.system(size: 22 + sizeOffset, weight: .semibold) }
    static var smallValue: Font { Font.system(size: 12 + sizeOffset, weight: .medium) }
}
