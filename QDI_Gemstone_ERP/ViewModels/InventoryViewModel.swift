import Foundation
import SwiftData

/// UI filter for inventory list
enum InventoryStatusFilter: String, CaseIterable {
    case all = "All"
    case available = "Available"
    case onMemo = "On Memo"
    case sold = "Sold"

    var gemstoneStatus: GemstoneStatus? {
        switch self {
        case .all: return nil
        case .available: return .available
        case .onMemo: return .onMemo
        case .sold: return .sold
        }
    }
}

/// Stone type filter for inventory
enum InventoryStoneTypeFilter: String, CaseIterable {
    case all = "All"
    case diamond = "Diamond"
    case emerald = "Emerald"
    case ruby = "Ruby"
    case tanzanite = "Tanzanite"
    case sapphire = "Sapphire"

    var stoneType: StoneType? {
        switch self {
        case .all: return nil
        case .diamond: return .diamond
        case .emerald: return .emerald
        case .ruby: return .ruby
        case .tanzanite: return .tanzanite
        case .sapphire: return .sapphire
        }
    }
}

/// Certified filter
enum CertifiedFilter: String, CaseIterable {
    case any = "Any"
    case yes = "Yes"
    case no = "No"
}

/// Represents a single active filter for pill display
enum ActiveFilterPill: Equatable {
    case stoneType(String)
    case shape(String)
    case certified(String)
    case treatment(String)
    case grouping(String)
    case caratRange(min: Double, max: Double)
    case sellRange(min: Decimal, max: Decimal)
    case color(String)
    case clarity(String)

    var label: String {
        switch self {
        case .stoneType(let s): return s
        case .shape(let s): return s
        case .certified(let s): return s
        case .treatment(let s): return s
        case .grouping(let s): return s
        case .caratRange(let min, let max):
            if min > 0 && max >= 9999 { return String(format: "> %.2f ct", min) }
            if min <= 0 && max < 9999 { return String(format: "< %.2f ct", max) }
            return String(format: "%.2f–%.2f ct", min, max)
        case .sellRange(let min, let max):
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = "USD"
            formatter.maximumFractionDigits = 0
            if min > 0 && max < 999_999 {
                return "\(formatter.string(from: min as NSDecimalNumber) ?? "\(min)")–\(formatter.string(from: max as NSDecimalNumber) ?? "\(max)")"
            } else if min > 0 {
                return "Sell > \(formatter.string(from: min as NSDecimalNumber) ?? "\(min)")"
            } else {
                return "Sell < \(formatter.string(from: max as NSDecimalNumber) ?? "\(max)")"
            }
        case .color(let s): return "Color \(s)"
        case .clarity(let s): return "Clarity \(s)"
        }
    }
}

@MainActor
@Observable
final class InventoryViewModel {
    var searchText: String = ""
    var statusFilter: InventoryStatusFilter = .all
    var stoneTypeFilter: InventoryStoneTypeFilter = .all

    /// Filter panel visibility (collapsing does NOT clear filters)
    var showFiltersPanel: Bool = false

    // Essential v1 filters
    var shapeFilter: String? = nil           // e.g. "Round", "Oval"
    var certifiedFilter: CertifiedFilter = .any
    var treatmentFilter: String? = nil
    var groupingFilter: String? = nil        // "S", "P", "L" or nil
    var caratMin: Double? = nil
    var caratMax: Double? = nil
    var sellMin: Decimal? = nil
    var sellMax: Decimal? = nil

    // Diamond-only filters
    var colorFilter: String? = nil           // e.g. "D-F", "G"
    var clarityFilter: String? = nil         // e.g. "VS1+", "IF"

    /// Whether any structured filter is active (excluding search and status)
    var hasActiveFilters: Bool {
        stoneTypeFilter != .all ||
        shapeFilter != nil ||
        certifiedFilter != .any ||
        treatmentFilter != nil ||
        groupingFilter != nil ||
        caratMin != nil ||
        caratMax != nil ||
        sellMin != nil ||
        sellMax != nil ||
        colorFilter != nil ||
        clarityFilter != nil
    }

    /// Pills for active filters (for display and removal)
    var activeFilterPills: [ActiveFilterPill] {
        var pills: [ActiveFilterPill] = []
        if stoneTypeFilter != .all {
            pills.append(.stoneType(stoneTypeFilter.rawValue))
        }
        if let s = shapeFilter, !s.isEmpty {
            pills.append(.shape(s))
        }
        if certifiedFilter != .any {
            pills.append(.certified(certifiedFilter.rawValue))
        }
        if let t = treatmentFilter, !t.isEmpty {
            pills.append(.treatment(t))
        }
        if let g = groupingFilter, !g.isEmpty {
            let label = g == "S" ? "Single" : (g == "P" ? "Pair" : "Lot")
            pills.append(.grouping(label))
        }
        if caratMin != nil || caratMax != nil {
            pills.append(.caratRange(min: caratMin ?? 0, max: caratMax ?? 9999))
        }
        if sellMin != nil || sellMax != nil {
            pills.append(.sellRange(min: sellMin ?? 0, max: sellMax ?? 999_999))
        }
        if let c = colorFilter, !c.isEmpty {
            pills.append(.color(c))
        }
        if let c = clarityFilter, !c.isEmpty {
            pills.append(.clarity(c))
        }
        return pills
    }

    /// Remove a specific pill
    func removePill(_ pill: ActiveFilterPill) {
        switch pill {
        case .stoneType: stoneTypeFilter = .all
        case .shape: shapeFilter = nil
        case .certified: certifiedFilter = .any
        case .treatment: treatmentFilter = nil
        case .grouping: groupingFilter = nil
        case .caratRange: caratMin = nil; caratMax = nil
        case .sellRange: sellMin = nil; sellMax = nil
        case .color: colorFilter = nil
        case .clarity: clarityFilter = nil
        }
    }

    /// Clear all structured filters (not search or status)
    func clearAllFilters() {
        stoneTypeFilter = .all
        shapeFilter = nil
        certifiedFilter = .any
        treatmentFilter = nil
        groupingFilter = nil
        caratMin = nil
        caratMax = nil
        sellMin = nil
        sellMax = nil
        colorFilter = nil
        clarityFilter = nil
    }

    /// Filter gemstones by search, status, and structured filters
    func filtered(from gemstones: [Gemstone]) -> [Gemstone] {
        var result = gemstones

        // Free-text search
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            result = result.filter { stone in
                stone.sku.lowercased().contains(q) ||
                stone.stoneType.rawValue.lowercased().contains(q) ||
                stone.color.lowercased().contains(q) ||
                stone.clarity.lowercased().contains(q) ||
                stone.cut.lowercased().contains(q) ||
                (stone.certNo ?? "").lowercased().contains(q) ||
                stone.origin.lowercased().contains(q)
            }
        }

        // Status
        if let status = statusFilter.gemstoneStatus {
            result = result.filter { $0.effectiveStatus == status }
        }

        // Stone type
        if let type = stoneTypeFilter.stoneType {
            result = result.filter { $0.stoneType == type }
        }

        // Shape
        if let s = shapeFilter, !s.isEmpty {
            result = result.filter { ($0.shape ?? "").lowercased().contains(s.lowercased()) }
        }

        // Certified
        switch certifiedFilter {
        case .any: break
        case .yes: result = result.filter { $0.hasCert == true }
        case .no: result = result.filter { $0.hasCert != true }
        }

        // Treatment
        if let t = treatmentFilter, !t.isEmpty {
            let treatment = t.lowercased()
            result = result.filter {
                ($0.treatment ?? $0.origin).lowercased().contains(treatment)
            }
        }

        // Grouping
        if let g = groupingFilter, !g.isEmpty {
            result = result.filter { ($0.grouping ?? "S") == g }
        }

        // Carat range
        if let min = caratMin { result = result.filter { $0.caratWeight >= min } }
        if let max = caratMax { result = result.filter { $0.caratWeight <= max } }

        // Sell range
        if let min = sellMin { result = result.filter { $0.sellPrice >= min } }
        if let max = sellMax { result = result.filter { $0.sellPrice <= max } }

        // Diamond-only: color, clarity
        if let c = colorFilter, !c.isEmpty {
            let color = c.uppercased()
            result = result.filter { stone in
                guard stone.stoneType == .diamond else { return false }
                return stone.color.uppercased().contains(color) || color.contains(stone.color.uppercased())
            }
        }
        if let c = clarityFilter, !c.isEmpty {
            let clarity = c.lowercased()
            result = result.filter { stone in
                guard stone.stoneType == .diamond else { return false }
                return stone.clarity.lowercased().contains(clarity)
            }
        }

        return result
    }

    /// Whether to show diamond-only filters (only when Diamond type is selected)
    var showDiamondFilters: Bool { stoneTypeFilter == .diamond }
}
