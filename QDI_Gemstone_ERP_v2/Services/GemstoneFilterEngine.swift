import Foundation

/// Stateless filtering and sorting engine for `[Gemstone]` arrays.
///
/// Extracts the duplicated filter/sort logic that previously lived in
/// GemstonesInventoryView, DiamondsInventoryView, etc. Each view calls
/// `GemstoneFilterEngine.apply(_:to:)` with its `InventoryFilterState`.
@MainActor
enum GemstoneFilterEngine {

    /// Screen-specific filtering/sorting behavior hints.
    enum ScreenHint {
        /// Default gemstone inventory behavior.
        case gemstones
        /// Diamond-specific: "K+" color means exclude D–J, "I1+" clarity means exclude IF–SI2.
        case diamonds
        /// Lot inventory: carat range filters on `effectiveRemainingCarats`.
        case lots
        /// Sold inventory: supports customer filter, date range, margin/customer sort.
        /// The `customerName` closure resolves a stone to its customer display name.
        case sold(customerName: (Gemstone) -> String)
    }

    // MARK: - Combined Filter + Sort

    /// Apply all filters from `state` to `stones`, then sort.
    static func apply(_ state: InventoryFilterState, to stones: [Gemstone], hint: ScreenHint = .gemstones) -> [Gemstone] {
        let filtered = filter(state, stones: stones, hint: hint)
        return sort(filtered, key: state.sortKey, ascending: state.sortAscending, hint: hint)
    }

    // MARK: - Filtering

    static func filter(_ state: InventoryFilterState, stones: [Gemstone], hint: ScreenHint = .gemstones) -> [Gemstone] {
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

        // Color — diamond-specific "K+" handling
        if let c = state.colorFilter, !c.isEmpty {
            switch hint {
            case .diamonds:
                if c == "K+" {
                    let early = ["D", "E", "F", "G", "H", "I", "J"]
                    result = result.filter { !early.contains($0.color.uppercased()) }
                } else {
                    result = result.filter { $0.color.uppercased() == c.uppercased() }
                }
            default:
                let cl = c.lowercased()
                result = result.filter {
                    $0.color.lowercased().contains(cl) ||
                    ($0.primaryColorVendor?.lowercased().contains(cl) == true)
                }
            }
        }

        // Clarity — diamond-specific "I1+" handling
        if let c = state.clarityFilter, !c.isEmpty {
            switch hint {
            case .diamonds:
                if c == "I1+" {
                    let better = ["IF", "VVS1", "VVS2", "VS1", "VS2", "SI1", "SI2"]
                    result = result.filter { !better.contains($0.clarity.uppercased()) }
                } else {
                    result = result.filter { $0.clarity.uppercased() == c.uppercased() }
                }
            default:
                result = result.filter { $0.clarity.lowercased().contains(c.lowercased()) }
            }
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

        // Carat range — lots use effectiveRemainingCarats
        switch hint {
        case .lots:
            if let min = state.caratMin { result = result.filter { $0.effectiveRemainingCarats >= min } }
            if let max = state.caratMax { result = result.filter { $0.effectiveRemainingCarats <= max } }
        default:
            if let min = state.caratMin { result = result.filter { $0.caratWeight >= min } }
            if let max = state.caratMax { result = result.filter { $0.caratWeight <= max } }
        }

        // Price range
        if let min = state.priceMin { result = result.filter { $0.sellPrice >= min } }
        if let max = state.priceMax { result = result.filter { $0.sellPrice <= max } }

        // Sold-specific: customer filter and date range
        if case .sold(let customerName) = hint {
            if !state.customerFilter.isEmpty {
                result = result.filter { customerName($0) == state.customerFilter }
            }
            if let from = state.dateFrom {
                result = result.filter { $0.createdAt >= from }
            }
            if let to = state.dateTo {
                result = result.filter { $0.createdAt <= Calendar.current.date(byAdding: .day, value: 1, to: to) ?? to }
            }
        }

        // Search
        let q = state.searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            switch hint {
            case .sold(let customerName):
                result = result.filter {
                    $0.sku.lowercased().contains(q) ||
                    $0.stoneType.rawValue.lowercased().contains(q) ||
                    $0.color.lowercased().contains(q) ||
                    $0.currentLocation.lowercased().contains(q) ||
                    customerName($0).lowercased().contains(q)
                }
            case .diamonds:
                result = result.filter {
                    $0.sku.lowercased().contains(q) ||
                    $0.color.lowercased().contains(q) ||
                    $0.clarity.lowercased().contains(q) ||
                    $0.certNo.lowercased().contains(q) ||
                    $0.shape.lowercased().contains(q)
                }
            default:
                result = result.filter {
                    $0.sku.lowercased().contains(q) ||
                    $0.stoneType.rawValue.lowercased().contains(q) ||
                    $0.color.lowercased().contains(q) ||
                    $0.origin.lowercased().contains(q) ||
                    $0.certNo.lowercased().contains(q)
                }
            }
        }

        return result
    }

    // MARK: - Sorting

    static func sort(_ stones: [Gemstone], key: String, ascending: Bool, hint: ScreenHint = .gemstones) -> [Gemstone] {
        stones.sorted { a, b in
            let asc: Bool
            switch key {
            case "type":
                asc = a.stoneType.rawValue.localizedCompare(b.stoneType.rawValue) == .orderedAscending
            case "shape":
                asc = a.shape.localizedCompare(b.shape) == .orderedAscending
            case "carat":
                asc = a.caratWeight < b.caratWeight
            case "carats":
                // Lot-specific: sort by effectiveRemainingCarats
                asc = a.effectiveRemainingCarats < b.effectiveRemainingCarats
            case "color":
                asc = a.color.localizedCompare(b.color) == .orderedAscending
            case "clarity":
                asc = a.clarity.localizedCompare(b.clarity) == .orderedAscending
            case "origin":
                asc = a.origin.localizedCompare(b.origin) == .orderedAscending
            case "price", "sell":
                asc = a.sellPrice < b.sellPrice
            case "cost":
                asc = a.costPrice < b.costPrice
            case "sold":
                asc = a.sellPrice < b.sellPrice
            case "status":
                asc = a.status.rawValue.localizedCompare(b.status.rawValue) == .orderedAscending
            case "dateAdded", "date":
                asc = a.createdAt < b.createdAt
            case "stones":
                asc = (a.numberOfStones ?? 0) < (b.numberOfStones ?? 0)
            case "avgCost":
                asc = a.effectiveAverageCost < b.effectiveAverageCost
            case "margin":
                let mA = a.costPrice > 0 ? ((a.sellPrice - a.costPrice) / a.costPrice) : 0
                let mB = b.costPrice > 0 ? ((b.sellPrice - b.costPrice) / b.costPrice) : 0
                asc = mA < mB
            case "customer":
                if case .sold(let customerName) = hint {
                    asc = customerName(a).localizedCompare(customerName(b)) == .orderedAscending
                } else {
                    asc = a.sku.localizedCompare(b.sku) == .orderedAscending
                }
            default: // "sku"
                asc = a.sku.localizedCompare(b.sku) == .orderedAscending
            }
            return ascending ? asc : !asc
        }
    }
}
