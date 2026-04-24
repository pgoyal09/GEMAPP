import Foundation

/// Stateless filtering and sorting engine for `[Gemstone]` arrays.
///
/// Extracts the duplicated filter/sort logic that previously lived in
/// GemstonesInventoryView, DiamondsInventoryView, etc. Each view calls
/// `GemstoneFilterEngine.apply(_:to:)` with its `InventoryFilterState`.
@MainActor
enum GemstoneFilterEngine {

    // MARK: - Combined Filter + Sort

    /// Apply all filters from `state` to `stones`, then sort.
    static func apply(_ state: InventoryFilterState, to stones: [Gemstone]) -> [Gemstone] {
        let filtered = filter(state, stones: stones)
        return sort(filtered, key: state.sortKey, ascending: state.sortAscending)
    }

    // MARK: - Filtering

    static func filter(_ state: InventoryFilterState, stones: [Gemstone]) -> [Gemstone] {
        var result = stones

        // Status
        if let s = state.statusFilter { result = result.filter { $0.status == s } }

        // Shape
        if let s = state.shapeFilter, !s.isEmpty {
            if s == "Other" {
                let top = ["round", "cushion", "oval", "pear", "emerald", "princess", "marquise"]
                result = result.filter { !top.contains($0.shape.lowercased()) }
            } else {
                result = result.filter { $0.shape.lowercased().contains(s.lowercased()) }
            }
        }

        // Grouping
        if let g = state.groupingFilter { result = result.filter { $0.grouping == g } }

        // Stone Type
        if let t = state.stoneTypeFilter { result = result.filter { $0.stoneType == t } }

        // Color
        if let c = state.colorFilter, !c.isEmpty {
            let cl = c.lowercased()
            result = result.filter {
                $0.color.lowercased().contains(cl) ||
                ($0.primaryColorVendor?.lowercased().contains(cl) == true)
            }
        }

        // Clarity
        if let c = state.clarityFilter, !c.isEmpty {
            result = result.filter { $0.clarity.lowercased().contains(c.lowercased()) }
        }

        // Cut
        if let c = state.cutFilter, !c.isEmpty {
            result = result.filter { $0.cut.lowercased() == c.lowercased() }
        }

        // Origin
        if let o = state.originFilter, !o.isEmpty {
            result = result.filter { $0.origin.lowercased().contains(o.lowercased()) }
        }

        // Treatment
        if let t = state.treatmentFilter, !t.isEmpty {
            let tl = t.lowercased()
            if tl == "none" {
                result = result.filter { $0.treatment.isEmpty || $0.treatment.lowercased() == "none" }
            } else {
                result = result.filter { $0.treatment.lowercased().contains(tl) }
            }
        }

        // Lab
        if let l = state.labFilter, !l.isEmpty {
            if l == "None" { result = result.filter { $0.certLab.isEmpty } }
            else { result = result.filter { $0.certLab.uppercased() == l.uppercased() } }
        }

        // Carat range
        if let min = state.caratMin { result = result.filter { $0.caratWeight >= min } }
        if let max = state.caratMax { result = result.filter { $0.caratWeight <= max } }

        // Price range
        if let min = state.priceMin { result = result.filter { $0.sellPrice >= min } }
        if let max = state.priceMax { result = result.filter { $0.sellPrice <= max } }

        // Search
        let q = state.searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            result = result.filter {
                $0.sku.lowercased().contains(q) ||
                $0.stoneType.rawValue.lowercased().contains(q) ||
                $0.color.lowercased().contains(q) ||
                $0.origin.lowercased().contains(q) ||
                $0.certNo.lowercased().contains(q)
            }
        }

        return result
    }

    // MARK: - Sorting

    static func sort(_ stones: [Gemstone], key: String, ascending: Bool) -> [Gemstone] {
        stones.sorted { a, b in
            let asc: Bool
            switch key {
            case "type":
                asc = a.stoneType.rawValue.localizedCompare(b.stoneType.rawValue) == .orderedAscending
            case "shape":
                asc = a.shape.localizedCompare(b.shape) == .orderedAscending
            case "carat":
                asc = a.caratWeight < b.caratWeight
            case "color":
                asc = a.color.localizedCompare(b.color) == .orderedAscending
            case "origin":
                asc = a.origin.localizedCompare(b.origin) == .orderedAscending
            case "price":
                asc = a.sellPrice < b.sellPrice
            case "cost":
                asc = a.costPrice < b.costPrice
            case "status":
                asc = a.status.rawValue.localizedCompare(b.status.rawValue) == .orderedAscending
            case "dateAdded":
                asc = a.createdAt < b.createdAt
            default: // "sku"
                asc = a.sku.localizedCompare(b.sku) == .orderedAscending
            }
            return ascending ? asc : !asc
        }
    }
}
