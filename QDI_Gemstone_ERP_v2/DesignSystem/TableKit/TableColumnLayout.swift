import SwiftUI

/// A single column definition in a proportional table layout.
struct ColumnDef {
    let id: String
    let weight: CGFloat
    let minWidth: CGFloat
    let alignment: Alignment

    init(_ id: String, weight: CGFloat, minWidth: CGFloat = 40, alignment: Alignment = .leading) {
        self.id = id
        self.weight = weight
        self.minWidth = minWidth
        self.alignment = alignment
    }
}

/// Computes actual column widths from weights and available container width.
struct TableColumnLayout {
    let columns: [ColumnDef]
    let spacing: CGFloat

    /// Given total available width, returns array of computed widths (one per column).
    func widths(for totalWidth: CGFloat) -> [CGFloat] {
        let totalSpacing = spacing * CGFloat(max(columns.count - 1, 0))
        let available = max(totalWidth - totalSpacing, 0)
        let totalWeight = columns.reduce(0) { $0 + $1.weight }
        guard totalWeight > 0 else { return columns.map { _ in 0 } }

        // First pass: allocate proportionally
        var result = columns.map { col in
            max(available * (col.weight / totalWeight), col.minWidth)
        }

        // If minWidths forced some columns wider, redistribute
        let used = result.reduce(0, +)
        if used > available {
            result = columns.map { $0.minWidth }
        }

        return result
    }
}
