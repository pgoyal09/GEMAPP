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

        var icon: String {
            switch self {
            case .neutral: return "circle"
            case .success: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .danger:  return "xmark.circle.fill"
            case .accent:  return "diamond.fill"
            }
        }
    }

    var body: some View {
        HStack(spacing: AppSpacing.compact) {
            Image(systemName: tone.icon)
                .font(AppTypography.caption)
            Text(title)
                .font(AppTypography.caption)
        }
        .foregroundStyle(tone.foreground)
        .padding(.horizontal, AppSpacing.comfortable)
        .padding(.vertical, AppSpacing.standard)
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.small, style: .continuous)
                .fill(tone.background)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Status: \(title)")
    }
}
