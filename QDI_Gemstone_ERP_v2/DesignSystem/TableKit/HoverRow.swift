import SwiftUI

/// Table row that highlights on hover and supports selection.
struct HoverRow<Content: View>: View {
    let isSelected: Bool
    var onTap: (() -> Void)? = nil
    @ViewBuilder let content: () -> Content

    @State private var isHovered = false
    @FocusState private var isFocused: Bool

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(spacing: 0) {
                content()
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, AppSpacing.m)
            .padding(.vertical, AppSpacing.s)
            .background(rowBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.s, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppCornerRadius.s, style: .continuous)
                    .strokeBorder(isFocused ? AppColors.primary : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .focusable()
        .focused($isFocused)
        .onHover { isHovered = $0 }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var rowBackground: some View {
        if isSelected {
            AppColors.primary.opacity(0.15)
        } else if isHovered {
            Color.white.opacity(0.04)
        } else {
            Color.clear
        }
    }
}
