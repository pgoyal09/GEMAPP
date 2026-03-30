import SwiftUI

/// Success/error toast that appears at the bottom of a view.
struct ToastOverlay: View {
    let message: String
    var isError: Bool = false

    var body: some View {
        VStack {
            Spacer()
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white)
                .padding(.horizontal, AppSpacing.l)
                .padding(.vertical, AppSpacing.m)
                .background(isError ? AppColors.danger : AppColors.success)
                .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.m, style: .continuous))
                .padding(.bottom, AppSpacing.xl)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
