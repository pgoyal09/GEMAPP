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
            .padding(.horizontal, AppSpacing.standard)
            .padding(.vertical, AppSpacing.compact)
            .background(rowBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.field, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppCornerRadius.field, style: .continuous)
                    .strokeBorder(isFocused ? AppColors.primary : Color.clear, lineWidth: 1)
            )
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
            Color.white.opacity(AppOpacity.whisper)
        } else {
            Color.clear
        }
    }
}
