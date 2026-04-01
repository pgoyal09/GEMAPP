import SwiftUI

/// Reusable table column header with optional sort indicator.
/// Set `flex: true` on exactly ONE column per table to make it stretch and fill available width.
struct TableHeader: View {
    let title: String
    var width: CGFloat? = nil
    var flex: Bool = false
    var alignment: Alignment = .leading
    var isSorted: Bool = false
    var ascending: Bool = true
    var onTap: (() -> Void)? = nil

    var body: some View {
        Group {
            if let onTap {
                Button(action: onTap) { label }
                    .buttonStyle(.plain)
            } else {
                label
            }
        }
        .modifier(ColumnFrameModifier(width: width, flex: flex, alignment: alignment))
        .accessibilityLabel(isSorted ? "\(title), sorted \(ascending ? "ascending" : "descending")" : title)
        .accessibilityAddTraits(onTap != nil ? .isButton : [])
    }

    private var label: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.inkSubtle)
            if isSorted {
                Image(systemName: ascending ? "chevron.up" : "chevron.down")
                    .font(AppTypography.sectionLabel.weight(.bold))
                    .foregroundStyle(AppColors.primary)
            }
        }
    }
}

/// Applies either a fixed-width or flex-width frame to a table column.
/// Reusable for both headers and row cells.
struct ColumnFrameModifier: ViewModifier {
    let width: CGFloat?
    let flex: Bool
    let alignment: Alignment

    func body(content: Content) -> some View {
        if flex, let w = width {
            content.frame(minWidth: w, maxWidth: .infinity, alignment: alignment)
        } else {
            content.frame(width: width, alignment: alignment)
        }
    }
}
