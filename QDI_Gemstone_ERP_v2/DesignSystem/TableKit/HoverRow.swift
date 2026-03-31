import SwiftUI

/// Table row that highlights on hover and supports selection.
struct HoverRow<Content: View>: View {
    let isSelected: Bool
    var onTap: (() -> Void)? = nil
    @ViewBuilder let content: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false
    @FocusState private var isFocused: Bool

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(spacing: 4) {
                content()
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, AppSpacing.section)
            .padding(.vertical, AppSpacing.comfortable)
            .background(rowBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppCornerRadius.medium, style: .continuous)
                    .strokeBorder(isFocused ? AppColors.primary : Color.clear, lineWidth: 2)
            )
            .scaleEffect(isHovered ? 1.005 : 1.0)
            .shadow(color: isHovered ? AppColors.softShadow.opacity(AppOpacity.medium) : Color.clear, radius: isHovered ? 4 : 0, y: 1)
        }
        .buttonStyle(.plain)
        .focusable()
        .focused($isFocused)
        .onHover { hovering in
            withAnimation(reduceMotion ? nil : AppAnimation.fast) { isHovered = hovering }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .transition(reduceMotion ? .opacity : .asymmetric(
            insertion: .opacity,
            removal: .opacity.combined(with: .move(edge: .trailing))
        ))
    }

    @ViewBuilder
    private var rowBackground: some View {
        if isSelected {
            AppColors.primary.opacity(AppOpacity.muted)
        } else if isHovered {
            Color.white.opacity(0.04)
        } else {
            Color.clear
        }
    }
}
