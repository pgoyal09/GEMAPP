import SwiftUI

// MARK: - Palette (soft sculpted gemstone aesthetic)

enum AppColors {
    static let background = Color(red: 0.93, green: 0.95, blue: 0.93)
    static let panelBackground = Color(red: 0.89, green: 0.92, blue: 0.90)
    static let cardBackground = Color(red: 0.95, green: 0.96, blue: 0.94)
    static let cardElevated = Color(red: 0.97, green: 0.98, blue: 0.96)

    static let primary = Color(red: 0.56, green: 0.69, blue: 0.66)      // dusty teal
    static let accent = Color(red: 0.86, green: 0.70, blue: 0.53)       // warm sand
    static let accentPeach = Color(red: 0.90, green: 0.76, blue: 0.66)
    static let success = Color(red: 0.47, green: 0.67, blue: 0.57)
    static let warning = Color(red: 0.83, green: 0.67, blue: 0.47)
    static let danger = Color(red: 0.72, green: 0.50, blue: 0.49)

    static let ink = Color(red: 0.22, green: 0.26, blue: 0.25)
    static let inkMuted = Color(red: 0.38, green: 0.44, blue: 0.42)
    static let inkSubtle = Color(red: 0.52, green: 0.57, blue: 0.55)

    static let cardStroke = Color(red: 0.72, green: 0.78, blue: 0.75).opacity(0.35)
    static let softHighlight = Color.white.opacity(0.75)
    static let softShadow = Color(red: 0.56, green: 0.62, blue: 0.60).opacity(0.22)

    static let shellGradient = LinearGradient(
        colors: [Color(red: 0.90, green: 0.93, blue: 0.91), Color(red: 0.93, green: 0.95, blue: 0.93)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
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

// MARK: - Typography

enum AppTypography {
    static let title = Font.system(size: 32, weight: .semibold, design: .rounded)
    static let heading = Font.system(size: 19, weight: .semibold, design: .rounded)
    static let body = Font.system(size: 14, weight: .regular, design: .rounded)
    static let caption = Font.system(size: 12, weight: .medium, design: .rounded)
    static let mono = Font.system(size: 13, weight: .medium, design: .monospaced)
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
                RoundedRectangle(cornerRadius: AppCornerRadius.l, style: .continuous)
                    .fill(AppColors.cardBackground)
                RoundedRectangle(cornerRadius: AppCornerRadius.l, style: .continuous)
                    .strokeBorder(AppColors.cardStroke, lineWidth: 1)
                if let accent {
                    RoundedRectangle(cornerRadius: AppCornerRadius.l, style: .continuous)
                        .stroke(accent.opacity(0.28), lineWidth: 1)
                }
            }
        )
        .shadow(color: AppShadows.outer.color, radius: AppShadows.outer.radius, x: AppShadows.outer.x, y: AppShadows.outer.y)
        .overlay(alignment: .topLeading) {
            Circle()
                .fill(Color.white.opacity(0.45))
                .frame(width: 18, height: 18)
                .offset(x: 10, y: 8)
                .blur(radius: 0.2)
        }
    }
}

struct AppStatusBadge: View {
    let title: String
    let tone: Tone

    enum Tone {
        case neutral, success, warning, danger, accent

        var foreground: Color {
            switch self {
            case .neutral: return AppColors.inkMuted
            case .success: return AppColors.success
            case .warning: return AppColors.warning
            case .danger: return AppColors.danger
            case .accent: return AppColors.primary
            }
        }

        var background: Color {
            foreground.opacity(0.13)
        }
    }

    var body: some View {
        Text(title)
            .font(AppTypography.caption)
            .foregroundStyle(tone.foreground)
            .padding(.horizontal, AppSpacing.s)
            .padding(.vertical, AppSpacing.xs)
            .background(
                Capsule(style: .continuous)
                    .fill(tone.background)
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
                RoundedRectangle(cornerRadius: AppCornerRadius.m, style: .continuous)
                    .fill(AppColors.cardElevated)
                    .stroke(AppColors.cardStroke, lineWidth: 1)
            )
    }
}

extension View {
    func appSearchField() -> some View { modifier(AppSearchFieldStyle()) }
}

// MARK: - Inspector Panel

enum InspectorWidth {
    static let min: CGFloat = 320
    static let ideal: CGFloat = 380
    static let max: CGFloat = 480
}
