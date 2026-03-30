import SwiftUI

enum AppColors {

    // MARK: - Backgrounds

    static let background       = Color(red: 0.04, green: 0.10, blue: 0.18)       // #0b1a2e
    static let panelBackground  = Color.white.opacity(0.04)
    static let cardBackground   = Color.white.opacity(0.05)
    static let cardElevated     = Color.white.opacity(0.06)

    // MARK: - Primary & Accent

    static let primary          = Color(red: 0.22, green: 0.74, blue: 0.97)       // #38bdf8
    static let accent           = Color(red: 0.22, green: 0.74, blue: 0.97).opacity(0.15)
    static let accentRose       = Color(red: 0.96, green: 0.45, blue: 0.71)       // #f472b6

    // MARK: - Semantic

    static let success          = Color(red: 0.20, green: 0.83, blue: 0.60)       // #34d399
    static let warning          = Color(red: 0.98, green: 0.75, blue: 0.14)       // #fbbf24
    static let danger           = Color(red: 0.96, green: 0.25, blue: 0.37)       // #f43f5e

    // MARK: - Text Hierarchy

    static let ink              = Color.white.opacity(0.90)
    static let inkMuted         = Color.white.opacity(0.65)
    static let inkSubtle        = Color.white.opacity(0.40)

    // MARK: - Surfaces & Effects

    static let cardStroke       = Color.white.opacity(0.08)
    static let softHighlight    = Color.white.opacity(0.04)
    static let softShadow       = Color(red: 0.22, green: 0.74, blue: 0.97).opacity(0.20)

    // MARK: - Stone Type Colors

    static let diamondColor     = Color(red: 0.22, green: 0.74, blue: 0.97)
    static let rubyColor        = Color(red: 0.96, green: 0.45, blue: 0.71)
    static let sapphireColor    = Color(red: 0.51, green: 0.55, blue: 0.98)
    static let emeraldColor     = Color(red: 0.20, green: 0.83, blue: 0.60)
    static let tanzaniteColor   = Color(red: 0.65, green: 0.55, blue: 0.98)

    static func stoneColor(for type: String) -> Color {
        switch type.lowercased() {
        case "diamond":   return diamondColor
        case "ruby":      return rubyColor
        case "sapphire":  return sapphireColor
        case "emerald":   return emeraldColor
        case "tanzanite": return tanzaniteColor
        default:          return Color.white.opacity(0.50)
        }
    }

    // MARK: - Gradients

    static let shellGradient = LinearGradient(
        colors: [
            Color(red: 0.04, green: 0.09, blue: 0.16),
            Color(red: 0.05, green: 0.13, blue: 0.22),
            Color(red: 0.06, green: 0.12, blue: 0.20),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let primaryGradient = LinearGradient(
        colors: [Color(red: 0.22, green: 0.74, blue: 0.97), Color(red: 0.24, green: 0.47, blue: 0.96)],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let violetGradient = LinearGradient(
        colors: [Color(red: 0.55, green: 0.36, blue: 0.98), Color(red: 0.42, green: 0.28, blue: 0.95)],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let emeraldGradient = LinearGradient(
        colors: [Color(red: 0.20, green: 0.83, blue: 0.60), Color(red: 0.13, green: 0.70, blue: 0.67)],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let amberGradient = LinearGradient(
        colors: [Color(red: 0.98, green: 0.75, blue: 0.14), Color(red: 0.95, green: 0.58, blue: 0.12)],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let roseGradient = LinearGradient(
        colors: [Color(red: 0.96, green: 0.45, blue: 0.71), Color(red: 0.96, green: 0.25, blue: 0.37)],
        startPoint: .leading,
        endPoint: .trailing
    )
}
