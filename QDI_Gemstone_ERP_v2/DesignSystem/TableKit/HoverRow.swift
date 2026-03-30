import SwiftUI

/// Table row that highlights on hover and supports selection.
struct HoverRow<Content: View>: View {
    let isSelected: Bool
    var onTap: (() -> Void)? = nil
    @ViewBuilder let content: () -> Content

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 0) {
            content()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, AppSpacing.m)
        .padding(.vertical, AppSpacing.s)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.s, style: .continuous))
        .onHover { isHovered = $0 }
        .onTapGesture { onTap?() }
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
