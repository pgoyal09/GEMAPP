import SwiftUI

enum AppTypography {
    /// Cached font size offset — reads UserDefaults once, updated via NotificationCenter
    nonisolated(unsafe) private static var _cachedOffset: CGFloat = {
        switch UserDefaults.standard.string(forKey: "displayFontSize") ?? "Small" {
        case "Medium": return 2
        case "Large":  return 4
        default:       return 0
        }
    }()

    private static var sizeOffset: CGFloat { _cachedOffset }

    /// Call this when the font size setting changes (e.g., from Settings view)
    static func refreshFontSize() {
        switch UserDefaults.standard.string(forKey: "displayFontSize") ?? "Small" {
        case "Medium": _cachedOffset = 2
        case "Large":  _cachedOffset = 4
        default:       _cachedOffset = 0
        }
    }

    static var title: Font       { .system(size: 28 + sizeOffset, weight: .semibold) }
    static var subtitle: Font    { .system(size: 20 + sizeOffset, weight: .semibold) }
    static var heading: Font     { .system(size: 15 + sizeOffset, weight: .semibold) }
    static var subheading: Font  { .system(size: 13 + sizeOffset, weight: .medium) }
    static var body: Font        { .system(size: 13 + sizeOffset, weight: .regular) }
    static var caption: Font     { .system(size: 11 + sizeOffset, weight: .medium) }
    static var mono: Font        { .system(size: 12 + sizeOffset, design: .monospaced).weight(.medium) }
    static var sectionLabel: Font { .system(size: 10 + sizeOffset, weight: .medium) }
    static var largeValue: Font  { .system(size: 22 + sizeOffset, weight: .semibold) }
    static var smallValue: Font  { .system(size: 12 + sizeOffset, weight: .medium) }

    // MARK: - Display Sizes (onboarding, splash, hero stats)
    static var displayTitle: Font { .system(size: 36 + sizeOffset, weight: .semibold, design: .rounded) }
    static var displayHero: Font  { .system(size: 48 + sizeOffset, weight: .semibold) }
    static var displayIcon: Font  { .system(size: 24 + sizeOffset, weight: .regular) }
    static var displaySmallIcon: Font { .system(size: 20 + sizeOffset, weight: .regular) }
    static var tinyLabel: Font   { .system(size: 9 + sizeOffset, weight: .bold) }
    static var footnote: Font    { .system(size: 10 + sizeOffset, weight: .regular) }
    static var monoSmall: Font   { .system(size: 12 + sizeOffset, design: .monospaced).weight(.medium) }
    static var bodyMono: Font    { .system(size: 13 + sizeOffset, design: .monospaced).weight(.medium) }
}
