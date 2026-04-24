import Foundation

/// Shared filter + search + sort state for inventory views.
///
/// Each inventory screen (diamonds, gemstones, lots, sold) can create its own
/// instance. The state is `@Observable` so SwiftUI views can bind to it directly.
/// Filtering and sorting logic lives in `GemstoneFilterEngine`; this type only
/// holds the state values.
@MainActor
@Observable
final class InventoryFilterState {

    // MARK: - Search

    var searchText: String = ""

    // MARK: - Sort

    var sortKey: String = "sku"
    var sortAscending: Bool = true

    // MARK: - Filters

    var statusFilter: GemstoneStatus?
    var shapeFilter: String?
    var groupingFilter: StoneGrouping?
    var stoneTypeFilter: StoneType?
    var colorFilter: String?
    var clarityFilter: String?
    var cutFilter: String?
    var originFilter: String?
    var treatmentFilter: String?
    var labFilter: String?

    // MARK: - Range Filters (numeric + text pairs)

    var caratMin: Double?
    var caratMax: Double?
    var caratMinText: String = ""
    var caratMaxText: String = ""

    var priceMin: Decimal?
    var priceMax: Decimal?
    var priceMinText: String = ""
    var priceMaxText: String = ""

    // MARK: - Search Focus

    var searchFieldFocusRequest: Bool = false

    // MARK: - Computed

    var hasActiveFilters: Bool {
        statusFilter != nil || shapeFilter != nil || groupingFilter != nil ||
        stoneTypeFilter != nil || colorFilter != nil || clarityFilter != nil ||
        originFilter != nil || treatmentFilter != nil || labFilter != nil ||
        cutFilter != nil ||
        caratMin != nil || caratMax != nil || priceMin != nil || priceMax != nil ||
        !searchText.isEmpty
    }

    var activeFilterCount: Int {
        var count = 0
        if statusFilter != nil { count += 1 }
        if shapeFilter != nil { count += 1 }
        if groupingFilter != nil { count += 1 }
        if stoneTypeFilter != nil { count += 1 }
        if colorFilter != nil { count += 1 }
        if clarityFilter != nil { count += 1 }
        if originFilter != nil { count += 1 }
        if treatmentFilter != nil { count += 1 }
        if labFilter != nil { count += 1 }
        if cutFilter != nil { count += 1 }
        if caratMin != nil || caratMax != nil { count += 1 }
        if priceMin != nil || priceMax != nil { count += 1 }
        return count
    }

    // MARK: - Actions

    func clearAll() {
        statusFilter = nil; shapeFilter = nil; groupingFilter = nil
        stoneTypeFilter = nil; colorFilter = nil; clarityFilter = nil
        originFilter = nil; treatmentFilter = nil; cutFilter = nil
        labFilter = nil; caratMin = nil; caratMax = nil
        priceMin = nil; priceMax = nil
        caratMinText = ""; caratMaxText = ""
        priceMinText = ""; priceMaxText = ""
        searchText = ""
        searchFieldFocusRequest = false
    }

    func toggleSort(_ key: String) {
        if sortKey == key { sortAscending.toggle() }
        else { sortKey = key; sortAscending = true }
    }

    /// Sync text fields → numeric values. Call from `.onChange` of text fields.
    func syncRangeValues() {
        caratMin = Double(caratMinText)
        caratMax = Double(caratMaxText)
        priceMin = Decimal(string: priceMinText)
        priceMax = Decimal(string: priceMaxText)
    }

    // MARK: - Preset Support

    func applyPreset(_ preset: FilterPreset) {
        stoneTypeFilter = preset.stoneTypeFilter.flatMap { StoneType(rawValue: $0) }
        colorFilter = preset.colorFilter
        clarityFilter = preset.clarityFilter
        cutFilter = preset.cutFilter
        originFilter = preset.originFilter
        treatmentFilter = preset.treatmentFilter
        labFilter = preset.labFilter
        shapeFilter = preset.shapeFilter
        statusFilter = preset.statusFilter.flatMap { GemstoneStatus(rawValue: $0) }
        groupingFilter = preset.groupingFilter.flatMap { StoneGrouping(rawValue: $0) }
        caratMin = preset.caratMin
        caratMax = preset.caratMax
        caratMinText = preset.caratMin.map { String(format: "%.2f", $0) } ?? ""
        caratMaxText = preset.caratMax.map { String(format: "%.2f", $0) } ?? ""
        priceMin = preset.priceMin
        priceMax = preset.priceMax
        priceMinText = preset.priceMin.map { "\($0)" } ?? ""
        priceMaxText = preset.priceMax.map { "\($0)" } ?? ""
    }

    func toPreset(name: String) -> FilterPreset {
        FilterPreset(
            name: name,
            shapeFilter: shapeFilter,
            colorFilter: colorFilter,
            clarityFilter: clarityFilter,
            cutFilter: cutFilter,
            labFilter: labFilter,
            statusFilter: statusFilter?.rawValue,
            groupingFilter: groupingFilter?.rawValue,
            stoneTypeFilter: stoneTypeFilter?.rawValue,
            originFilter: originFilter,
            treatmentFilter: treatmentFilter,
            caratMin: caratMin,
            caratMax: caratMax,
            priceMin: priceMin,
            priceMax: priceMax
        )
    }
}
