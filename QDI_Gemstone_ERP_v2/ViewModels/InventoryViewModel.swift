import Foundation
import SwiftData

// MARK: - Filter Types

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

enum CertifiedFilter: String, CaseIterable {
    case any = "Any"
    case yes = "Yes"
    case no = "No"
}

/// Represents a single active filter for pill display and removal.
enum ActiveFilterPill: Equatable {
    case stoneType(StoneType)
    case shape(String)
    case certified(String)
    case treatment(String)
    case grouping(StoneGrouping)
    case caratRange(min: Double, max: Double)
    case sellRange(min: Decimal, max: Decimal)
    case color(String)
    case clarity(String)

    var label: String {
        switch self {
        case .stoneType(let t): return t.rawValue
        case .shape(let s): return s
        case .certified(let s): return "Cert: \(s)"
        case .treatment(let s): return s
        case .grouping(let g): return g.displayName
        case .caratRange(let min, let max):
            if min > 0 && max >= 9999 { return String(format: "> %.2f ct", min) }
            if min <= 0 && max < 9999 { return String(format: "< %.2f ct", max) }
            return String(format: "%.2f–%.2f ct", min, max)
        case .sellRange(let min, let max):
            let fmt = NumberFormatter()
            fmt.numberStyle = .currency
            fmt.currencyCode = "USD"
            fmt.maximumFractionDigits = 0
            let fmtMin = fmt.string(from: min as NSDecimalNumber) ?? "\(min)"
            let fmtMax = fmt.string(from: max as NSDecimalNumber) ?? "\(max)"
            if min > 0 && max < 999_999 { return "\(fmtMin)–\(fmtMax)" }
            if min > 0 { return "Sell > \(fmtMin)" }
            return "Sell < \(fmtMax)"
        case .color(let s): return "Color \(s)"
        case .clarity(let s): return "Clarity \(s)"
        }
    }
}

// MARK: - ViewModel

@MainActor
@Observable
final class InventoryViewModel {

    // MARK: - Filter State

    var searchText: String = ""
    var statusFilter: InventoryStatusFilter = .all
    var stoneTypeFilter: StoneType? = nil
    var showFiltersPanel: Bool = false

    var shapeFilter: String? = nil
    var certifiedFilter: CertifiedFilter = .any
    var treatmentFilter: String? = nil
    var groupingFilter: StoneGrouping? = nil
    var caratMin: Double? = nil
    var caratMax: Double? = nil
    var sellMin: Decimal? = nil
    var sellMax: Decimal? = nil
    var colorFilter: String? = nil
    var clarityFilter: String? = nil

    // MARK: - Selection

    var selectedStoneID: PersistentIdentifier? = nil

    // MARK: - Computed

    var hasActiveFilters: Bool {
        stoneTypeFilter != nil ||
        shapeFilter != nil ||
        certifiedFilter != .any ||
        treatmentFilter != nil ||
        groupingFilter != nil ||
        caratMin != nil || caratMax != nil ||
        sellMin != nil || sellMax != nil ||
        colorFilter != nil || clarityFilter != nil
    }

    var showDiamondFilters: Bool { stoneTypeFilter == .diamond }

    var activeFilterPills: [ActiveFilterPill] {
        var pills: [ActiveFilterPill] = []
        if let t = stoneTypeFilter { pills.append(.stoneType(t)) }
        if let s = shapeFilter, !s.isEmpty { pills.append(.shape(s)) }
        if certifiedFilter != .any { pills.append(.certified(certifiedFilter.rawValue)) }
        if let t = treatmentFilter, !t.isEmpty { pills.append(.treatment(t)) }
        if let g = groupingFilter { pills.append(.grouping(g)) }
        if caratMin != nil || caratMax != nil {
            pills.append(.caratRange(min: caratMin ?? 0, max: caratMax ?? 9999))
        }
        if sellMin != nil || sellMax != nil {
            pills.append(.sellRange(min: sellMin ?? 0, max: sellMax ?? 999_999))
        }
        if let c = colorFilter, !c.isEmpty { pills.append(.color(c)) }
        if let c = clarityFilter, !c.isEmpty { pills.append(.clarity(c)) }
        return pills
    }

    // MARK: - Actions

    func removePill(_ pill: ActiveFilterPill) {
        switch pill {
        case .stoneType: stoneTypeFilter = nil
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

    func clearAllFilters() {
        stoneTypeFilter = nil
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

    /// Filter gemstones by search, status, and structured filters.
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
                stone.certNo.lowercased().contains(q) ||
                stone.origin.lowercased().contains(q)
            }
        }

        // Status
        if let status = statusFilter.gemstoneStatus {
            result = result.filter { $0.status == status }
        }

        // Stone type
        if let type = stoneTypeFilter {
            result = result.filter { $0.stoneType == type }
        }

        // Shape
        if let s = shapeFilter, !s.isEmpty {
            result = result.filter { $0.shape.lowercased().contains(s.lowercased()) }
        }

        // Certified
        switch certifiedFilter {
        case .any: break
        case .yes: result = result.filter { $0.hasCert }
        case .no: result = result.filter { !$0.hasCert }
        }

        // Treatment
        if let t = treatmentFilter, !t.isEmpty {
            let treatment = t.lowercased()
            result = result.filter { $0.treatment.lowercased().contains(treatment) }
        }

        // Grouping
        if let g = groupingFilter {
            result = result.filter { $0.grouping == g }
        }

        // Carat range
        if let min = caratMin { result = result.filter { $0.caratWeight >= min } }
        if let max = caratMax { result = result.filter { $0.caratWeight <= max } }

        // Sell range
        if let min = sellMin { result = result.filter { $0.sellPrice >= min } }
        if let max = sellMax { result = result.filter { $0.sellPrice <= max } }

        // Diamond-only filters
        if let c = colorFilter, !c.isEmpty {
            let color = c.uppercased()
            result = result.filter { $0.stoneType == .diamond && $0.color.uppercased().contains(color) }
        }
        if let c = clarityFilter, !c.isEmpty {
            let clarity = c.lowercased()
            result = result.filter { $0.stoneType == .diamond && $0.clarity.lowercased().contains(clarity) }
        }

        return result
    }
}
