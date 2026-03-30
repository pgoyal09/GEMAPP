import SwiftUI
import Foundation

// MARK: - Palette (dark glass-morphism — VitalArc merged)

enum AppColors {
    // Backgrounds
    static let background       = Color(red: 0.04, green: 0.10, blue: 0.18)       // #0B1A2E
    static let panelBackground  = Color.white.opacity(0.04)
    static let cardBackground   = Color.white.opacity(0.05)
    static let cardElevated     = Color.white.opacity(0.06)

    // Primary & accent
    static let primary          = Color(red: 0.22, green: 0.74, blue: 0.97)       // cyan #38BDF8
    static let accent           = Color(red: 0.22, green: 0.74, blue: 0.97).opacity(0.15)
    static let accentPeach      = Color(red: 0.96, green: 0.45, blue: 0.71)       // rose #F472B6

    // Semantic
    static let success          = Color(red: 0.20, green: 0.83, blue: 0.60)       // emerald #34D399
    static let successDeep      = Color(red: 0.00, green: 0.72, blue: 0.58)       // #00B894 (VitalArc)
    static let warning          = Color(red: 0.98, green: 0.75, blue: 0.14)       // amber #FBBF24
    static let danger           = Color(red: 0.96, green: 0.25, blue: 0.37)       // rose #F43F5E
    static let info             = Color(red: 0.48, green: 0.55, blue: 0.87)       // indigo #7B8CDE (VitalArc)

    // Text hierarchy
    static let ink              = Color.white.opacity(0.90)
    static let inkMuted         = Color.white.opacity(0.50)
    static let inkSubtle        = Color.white.opacity(0.30)

    // Surfaces & effects
    static let cardStroke       = Color.white.opacity(0.08)
    static let softHighlight    = Color.white.opacity(0.04)
    static let softShadow       = Color(red: 0.22, green: 0.74, blue: 0.97).opacity(0.20)

    // Hero card tier (VitalArc)
    static let heroCardBackground = Color(red: 0.10, green: 0.13, blue: 0.21)     // #1A2235
    static let heroGlassBorder    = Color.white.opacity(0.14)

    // Context card tier (VitalArc)
    static let contextCardBackground = Color.white.opacity(0.02)
    static let contextGlassBorder    = Color.white.opacity(0.03)

    // Stone-type colors
    static let diamondColor     = Color(red: 0.22, green: 0.74, blue: 0.97)       // cyan
    static let rubyColor        = Color(red: 0.96, green: 0.45, blue: 0.71)       // rose
    static let sapphireColor    = Color(red: 0.51, green: 0.55, blue: 0.98)       // indigo
    static let emeraldColor     = Color(red: 0.20, green: 0.83, blue: 0.60)       // emerald
    static let tanzaniteColor   = Color(red: 0.65, green: 0.55, blue: 0.98)       // violet

    // Gradients
    static let shellGradient = LinearGradient(
        colors: [
            Color(red: 0.04, green: 0.09, blue: 0.16),  // #0A1628
            Color(red: 0.05, green: 0.13, blue: 0.22),  // #0D2137
            Color(red: 0.06, green: 0.12, blue: 0.20),  // #0F1F33
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

    static let heroGradient = LinearGradient(
        colors: [Color(red: 0.04, green: 0.04, blue: 0.06), Color(red: 0.10, green: 0.10, blue: 0.18)],
        startPoint: .top,
        endPoint: .bottom
    )

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
}

// MARK: - Spacing

enum AppSpacing {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 6
    static let s: CGFloat = 10
    static let m: CGFloat = 14
    static let l: CGFloat = 20
    static let xl: CGFloat = 28
    static let xxl: CGFloat = 36
}

// MARK: - Corner Radius

enum AppCornerRadius {
    static let s: CGFloat = 10
    static let m: CGFloat = 16
    static let l: CGFloat = 22
    static let xl: CGFloat = 30
}

// MARK: - Typography (merged VitalArc + GEMAPP)

enum AppTypography {
    static let heroMetric   = Font.system(size: 36, weight: .bold, design: .rounded)
    static let title        = Font.system(size: 32, weight: .semibold, design: .default)
    static let heading      = Font.system(size: 19, weight: .semibold, design: .default)
    static let largeValue   = Font.system(size: 28, weight: .semibold, design: .default)
    static let body         = Font.system(size: 14, weight: .regular, design: .default)
    static let bodyMedium   = Font.system(size: 14, weight: .medium, design: .default)
    static let caption      = Font.system(size: 12, weight: .medium, design: .default)
    static let sectionLabel = Font.system(size: 10, weight: .medium, design: .default)
    static let mono         = Font.system(size: 13, weight: .medium, design: .monospaced)
    static let metric       = Font.system(size: 24, weight: .semibold, design: .rounded)
    static let priceDisplay = Font.system(size: 20, weight: .semibold, design: .monospaced)
    static let caratDisplay = Font.system(size: 16, weight: .medium, design: .rounded)
}

// MARK: - Animation Tokens (VitalArc)

enum AppAnimation {
    static let hover       = Animation.easeInOut(duration: 0.12)
    static let expand      = Animation.easeInOut(duration: 0.20)
    static let sheetSpring = Animation.spring(response: 0.35, dampingFraction: 0.85)
    static let tabSwitch   = Animation.easeInOut(duration: 0.15)
    static let valueUpdate = Animation.spring(response: 0.40, dampingFraction: 0.80)
    static let shimmer     = Animation.linear(duration: 1.5).repeatForever(autoreverses: false)
}

// MARK: - Shadows

enum AppShadows {
    static let outer = (color: AppColors.softShadow, radius: CGFloat(16), x: CGFloat(0), y: CGFloat(10))
    static let innerHighlight = (color: AppColors.softHighlight, radius: CGFloat(8), x: CGFloat(-2), y: CGFloat(-2))
}

// MARK: - Reusable Primitives

struct AppSurfaceCard<Content: View>: View {
    var padding: CGFloat = AppSpacing.l
    var accent: Color? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            content
        }
        .padding(padding)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: AppCornerRadius.m, style: .continuous)
                    .fill(AppColors.cardBackground)
                RoundedRectangle(cornerRadius: AppCornerRadius.m, style: .continuous)
                    .strokeBorder(AppColors.cardStroke, lineWidth: 1)
                if let accent {
                    RoundedRectangle(cornerRadius: AppCornerRadius.m, style: .continuous)
                        .stroke(accent.opacity(0.20), lineWidth: 1)
                }
            }
        )
    }
}

struct GlassCard<Content: View>: View {
    var padding: CGFloat = AppSpacing.l
    var cornerRadius: CGFloat = AppCornerRadius.m
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(AppColors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(AppColors.cardStroke, lineWidth: 1)
                    )
            )
    }
}

// MARK: - Card Tier Components (VitalArc)

struct HeroCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) { content }
            .padding(AppSpacing.l)
            .background(
                RoundedRectangle(cornerRadius: AppCornerRadius.m, style: .continuous)
                    .fill(AppColors.heroCardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppCornerRadius.m, style: .continuous)
                            .strokeBorder(AppColors.heroGlassBorder, lineWidth: 1)
                    )
            )
            .shadow(color: AppColors.softShadow, radius: 16, y: 8)
    }
}

struct ContextCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) { content }
            .padding(AppSpacing.m)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppColors.contextCardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(AppColors.contextGlassBorder, lineWidth: 0.5)
                    )
            )
    }
}

// MARK: - Shimmer Loading (VitalArc)

struct ShimmerLine: View {
    var maxWidth: CGFloat = .infinity
    var height: CGFloat = 12

    @State private var phase: CGFloat = 0

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.white.opacity(0.12))
            .frame(maxWidth: maxWidth)
            .frame(height: height)
            .overlay(
                LinearGradient(
                    colors: [.clear, Color.white.opacity(0.08), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .onAppear {
                withAnimation(AppAnimation.shimmer) { phase = 200 }
            }
    }
}

// MARK: - Buttons

struct GradientButton: View {
    let title: String
    var icon: String? = nil
    var gradient: LinearGradient = AppColors.primaryGradient
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .medium))
                }
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(gradient, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: AppColors.primary.opacity(0.20), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }
}

struct StoneTypeBadge: View {
    let type: String

    var body: some View {
        Text(type)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(AppColors.stoneColor(for: type))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(AppColors.stoneColor(for: type).opacity(0.15))
            )
    }
}

struct AppStatusBadge: View {
    let title: String
    let tone: Tone

    enum Tone {
        case neutral, success, warning, danger, accent, info

        var foreground: Color {
            switch self {
            case .neutral: return AppColors.inkMuted
            case .success: return AppColors.success
            case .warning: return AppColors.warning
            case .danger: return AppColors.danger
            case .accent: return AppColors.primary
            case .info: return AppColors.info
            }
        }

        var background: Color {
            foreground.opacity(0.15)
        }
    }

    var body: some View {
        Text(title)
            .font(AppTypography.caption)
            .foregroundStyle(tone.foreground)
            .padding(.horizontal, AppSpacing.s)
            .padding(.vertical, AppSpacing.xs)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(tone.background)
            )
    }
}

struct FilterPill: View {
    let title: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isActive ? AppColors.primary : Color.white.opacity(0.35))
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isActive ? AppColors.primary.opacity(0.20) : Color.white.opacity(0.03))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(
                                    isActive ? AppColors.primary.opacity(0.20) : Color.white.opacity(0.06),
                                    lineWidth: 1
                                )
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Field Modifiers

struct GlassFieldModifier: ViewModifier {
    var violet: Bool = false

    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .foregroundStyle(AppColors.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(
                                violet ? AppColors.tanzaniteColor.opacity(0.30) : Color.white.opacity(0.08),
                                lineWidth: 1
                            )
                    )
            )
    }
}

struct GradientButtonStyle: ButtonStyle {
    var gradient: LinearGradient = AppColors.primaryGradient
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(gradient, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1.0) : 0.4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .shadow(color: AppColors.primary.opacity(isEnabled ? 0.18 : 0), radius: 8, y: 4)
            .animation(AppAnimation.hover, value: configuration.isPressed)
    }
}

struct OutlineGlassButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(isEnabled ? AppColors.ink : AppColors.inkMuted)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.08 : 0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                    )
            )
            .opacity(isEnabled ? 1.0 : 0.5)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(AppAnimation.hover, value: configuration.isPressed)
    }
}

// MARK: - Search

struct GlassSearchField: View {
    @Binding var text: String
    var placeholder: String = "Search..."

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(Color.white.opacity(0.25))
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(Color.white.opacity(0.80))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

struct AppSearchFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .padding(.horizontal, AppSpacing.m)
            .padding(.vertical, AppSpacing.s)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
    }
}

// MARK: - View Modifiers

extension View {
    func glassField(violet: Bool = false) -> some View { modifier(GlassFieldModifier(violet: violet)) }
    func appSearchField() -> some View { modifier(AppSearchFieldStyle()) }

    func glassCardBackground(radius: CGFloat = AppCornerRadius.m) -> some View {
        self.background(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(AppColors.cardStroke, lineWidth: 1)
                )
        )
    }

    func heroGlass(radius: CGFloat = AppCornerRadius.m) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(AppColors.heroCardBackground)
            )
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(AppColors.heroGlassBorder, lineWidth: 1)
            )
            .shadow(color: AppColors.softShadow, radius: 12, y: 6)
    }

    func contextGlass(radius: CGFloat = 12) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(AppColors.contextCardBackground)
            )
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(AppColors.contextGlassBorder, lineWidth: 0.5)
            )
    }

    /// Label caption style: caption font + white 40% foreground. Used for form labels.
    func captionLabel() -> some View {
        self.font(AppTypography.caption).foregroundStyle(Color.white.opacity(0.40))
    }

    /// Section header style: small uppercase + tracking. Used for form section headers.
    func sectionLabel(tracking: CGFloat = 1.5) -> some View {
        self.font(AppTypography.sectionLabel).foregroundStyle(AppColors.inkSubtle).tracking(tracking)
    }

    func glassTable() -> some View {
        self
            .tableStyle(.inset)
            .scrollContentBackground(.hidden)
            .background(
                RoundedRectangle(cornerRadius: AppCornerRadius.m, style: .continuous)
                    .fill(AppColors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppCornerRadius.m, style: .continuous)
                            .strokeBorder(AppColors.cardStroke, lineWidth: 1)
                    )
            )
    }
}

// MARK: - Hoverable Table Row

struct AppTableHoverRow<Content: View>: View {
    let isSelected: Bool
    var verticalPadding: CGFloat = 10
    var horizontalPadding: CGFloat = 0
    let onTap: () -> Void
    @ViewBuilder let content: () -> Content
    @State private var isHovered = false

    var body: some View {
        content()
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, horizontalPadding)
            .background(
                isSelected
                    ? AppColors.primary.opacity(0.10)
                    : (isHovered ? Color.white.opacity(0.04) : Color.clear)
            )
            .contentShape(Rectangle())
            .onTapGesture { onTap() }
            .onHover { isHovered = $0 }
            .animation(AppAnimation.hover, value: isHovered)
    }
}

struct AppTableHeader: View {
    struct Column {
        let title: String
        let width: CGFloat?
        let alignment: Alignment
        init(_ title: String, width: CGFloat? = nil, alignment: Alignment = .leading) {
            self.title = title; self.width = width; self.alignment = alignment
        }
    }
    let columns: [Column]
    var body: some View {
        HStack(spacing: 0) {
            ForEach(columns.indices, id: \.self) { i in
                let col = columns[i]
                if let w = col.width {
                    Text(col.title).frame(width: w, alignment: col.alignment).padding(.horizontal, 4)
                } else {
                    Text(col.title).frame(maxWidth: .infinity, alignment: col.alignment).padding(.horizontal, 4)
                }
            }
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(AppColors.inkSubtle)
        .tracking(0.5)
        .padding(.horizontal, AppSpacing.l)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.03))
    }
}

// MARK: - Inspector Panel

enum InspectorWidth {
    static let min: CGFloat = 320
    static let ideal: CGFloat = 380
    static let max: CGFloat = 480
}

// MARK: - App Notifications

extension Notification.Name {
    /// Posted when memo or invoice data is saved. Dashboard listens to refresh totals.
    static let memoOrInvoiceDidSave = Notification.Name("com.qdi.gemapp.memoOrInvoiceDidSave")
}
