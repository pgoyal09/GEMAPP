import SwiftUI

/// Success/error toast with glass-morphism treatment matching GlassCard.
struct ToastOverlay: View {
    let message: String
    var isError: Bool = false
    var undoAction: (() -> Void)? = nil

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var icon: String {
        isError ? "xmark.circle.fill" : "checkmark.circle.fill"
    }

    private var tint: Color {
        isError ? AppColors.danger : AppColors.success
    }

    var body: some View {
        VStack {
            Spacer()
            HStack(spacing: AppSpacing.standard) {
                Image(systemName: icon)
                    .font(AppTypography.body)
                    .foregroundStyle(tint)
                Text(message)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.ink)
                if let undoAction {
                    Button("Undo") { undoAction() }
                        .font(AppTypography.body.weight(.semibold))
                        .foregroundStyle(AppColors.primary)
                        .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppSpacing.hero)
            .padding(.vertical, AppSpacing.comfortable)
            .background(
                RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                    .fill(reduceTransparency ? AppColors.cardElevated : AppColors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                            .strokeBorder(tint.opacity(AppOpacity.medium), lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(AppOpacity.medium), radius: 12, y: 6)
            .padding(.bottom, AppSpacing.hero)
        }
        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
        .animation(reduceMotion ? nil : AppAnimation.standard, value: message)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isError ? "Error: \(message)" : "Success: \(message)")
    }
}
