import SwiftUI

enum AppOpacity {
    /// 0.03 — near-invisible hover/highlight
    static let faint: Double = 0.03
    /// 0.04 — minimal background tint
    static let whisper: Double = 0.04
    /// 0.05 — soft background, card hover
    static let soft: Double = 0.05
    /// 0.06 — dim shimmer/filter overlays
    static let dim: Double = 0.06
    /// 0.08 — barely visible tints, glass fills
    static let subtle: Double = 0.08
    /// 0.15 — muted backgrounds, badge fills
    static let muted: Double = 0.15
    /// 0.30 — medium emphasis borders, strokes
    static let medium: Double = 0.30
    /// 0.60 — strong de-emphasis, secondary icons
    static let strong: Double = 0.60
    /// 1.0 — full opacity
    static let full: Double = 1.0
}
