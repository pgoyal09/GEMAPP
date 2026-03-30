import SwiftUI

struct StatusBadge: View {
    let title: String
    let tone: Tone

    enum Tone {
        case neutral, success, warning, danger, accent

        var foreground: Color {
            switch self {
            case .neutral: return AppColors.inkMuted
            case .success: return AppColors.success
            case .warning: return AppColors.warning
            case .danger:  return AppColors.danger
            case .accent:  return AppColors.primary
            }
        }

        var background: Color { foreground.opacity(0.15) }
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
            .accessibilityLabel("Status: \(title)")
    }
}
