import SwiftUI

struct GlassSearchField: View {
    @Binding var text: String
    var placeholder: String = "Search..."
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isFocused: Bool

    /// Optional external focus binding for programmatic focus (e.g. keyboard shortcuts).
    /// When provided, changes to the external binding are synced to the internal FocusState.
    var requestFocus: Binding<Bool>?

    var body: some View {
        HStack(spacing: AppSpacing.standard) {
            Image(systemName: "magnifyingglass")
                .font(AppTypography.body)
                .foregroundStyle(isFocused ? AppColors.primary : AppColors.inkSubtle)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(AppTypography.smallValue)
                .foregroundStyle(AppColors.ink)
                .focused($isFocused)
                .accessibilityLabel(placeholder)
        }
        .padding(.horizontal, AppSpacing.section)
        .padding(.vertical, AppSpacing.comfortable)
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.medium, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: AppCornerRadius.medium, style: .continuous)
                        .strokeBorder(
                            isFocused ? AppColors.primary : Color.white.opacity(AppOpacity.subtle),
                            lineWidth: isFocused ? 1.5 : 1
                        )
                )
        )
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: isFocused)
        .onChange(of: requestFocus?.wrappedValue) { _, newValue in
            if newValue == true {
                isFocused = true
                requestFocus?.wrappedValue = false
            }
        }
    }
}
