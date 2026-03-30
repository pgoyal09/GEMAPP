import SwiftUI

struct GradientButton: View {
    let title: String
    var icon: String? = nil
    var gradient: LinearGradient = AppColors.primaryGradient
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(AppTypography.smallValue)
                }
                Text(title)
                    .font(AppTypography.smallValue)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, AppSpacing.standard)
            .padding(.vertical, AppSpacing.compact)
            .background(gradient, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: AppColors.primary.opacity(0.20), radius: 8, y: 4)
            .scaleEffect(isPressed ? 0.97 : 1.0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            withAnimation(AppAnimation.spring) { isPressed = pressing }
        }, perform: {})
    }
}
