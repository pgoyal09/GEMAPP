import SwiftUI

/// Reusable table column header with optional sort indicator.
struct TableHeader: View {
    let title: String
    var width: CGFloat? = nil
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
        .frame(minWidth: width, maxWidth: .infinity, alignment: alignment)
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
