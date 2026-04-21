import Foundation
import SwiftData
import os

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
            let fmtMin = min.asCurrency
            let fmtMax = max.asCurrency
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
final class InventoryViewModel: SortableViewModel {

    // MARK: - Sort State

    var sortKey: String = "dateAdded"
    var sortAscending: Bool = false

    // MARK: - Filter State

    var searchText: String = ""
    var statusFilter: InventoryStatusFilter = {
        InventoryStatusFilter(rawValue: UserDefaults.standard.string(forKey: "inv.statusFilter") ?? "") ?? .all
    }() {
        didSet { UserDefaults.standard.set(statusFilter.rawValue, forKey: "inv.statusFilter") }
    }
    var stoneTypeFilter: StoneType? = nil
    var showFiltersPanel: Bool = false

    var shapeFilter: String? = nil
    var certifiedFilter: CertifiedFilter = .any
    var treatmentFilter: String? = nil
    var groupingFilter: StoneGrouping? = nil
    var caratMin: Double? = nil
    var caratMax: Double? = nil
    var caratMinText: String = ""
    var caratMaxText: String = ""
    var sellMin: Decimal? = nil
    var sellMax: Decimal? = nil
    var sellMinText: String = ""
    var sellMaxText: String = ""
    var colorFilter: String? = nil
    var clarityFilter: String? = nil
    var cutFilter: String? = nil
    var labFilter: String? = nil
    var statusFilterGemstone: GemstoneStatus? = nil
    var originFilter: String? = nil

    // MARK: - Pagination

    private(set) var fetchedStones: [Gemstone] = []
    private(set) var hasMore = true
    private let pageSize = 50
    private var currentOffset = 0
    private var currentMode: InventoryListMode = .current

    func fetchPage(context: ModelContext, mode: InventoryListMode = .current) {
        currentMode = mode
        currentOffset = 0
        hasMore = true
        // SwiftData #Predicate does not support custom enum types as captured constants.
        // Fetch all stones and filter in memory instead.
        let descriptor = FetchDescriptor<Gemstone>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        do {
            let allStones = try context.fetch(descriptor)
            let filtered = applyModeAndStatusFilter(allStones)
            fetchedStones = Array(filtered.prefix(pageSize))
        } catch {
            AppLogger.data.error("Inventory fetch failed: \(error.localizedDescription, privacy: .public)")
            fetchedStones = []
        }
        currentOffset = fetchedStones.count
        hasMore = fetchedStones.count == pageSize
    }

    func loadMore(context: ModelContext) {
        guard hasMore else { return }
        let descriptor = FetchDescriptor<Gemstone>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let page: [Gemstone]
        do {
            let allStones = try context.fetch(descriptor)
            let filtered = applyModeAndStatusFilter(allStones)
            page = Array(filtered.dropFirst(currentOffset).prefix(pageSize))
        } catch {
            AppLogger.data.error("Inventory loadMore failed: \(error.localizedDescription, privacy: .public)")
            return
        }
        fetchedStones.append(contentsOf: page)
        currentOffset += page.count
        hasMore = page.count == pageSize
    }

    /// Re-fetch the first page using current predicate filters.
    func refetch(context: ModelContext) {
        fetchPage(context: context, mode: currentMode)
    }

    // MARK: - In-Memory Filter

    /// Filters stones by mode, status, and stone type in memory
    /// (replaces #Predicate which cannot capture custom enum types).
    private func applyModeAndStatusFilter(_ stones: [Gemstone]) -> [Gemstone] {
        stones.filter { stone in
            if currentMode == .sold {
                guard stone.status == .sold else { return false }
                if let type = stoneTypeFilter { return stone.stoneType == type }
                return true
            }

            guard stone.grouping != .lot else { return false }

            switch statusFilter {
            case .available:
                guard stone.status == .available else { return false }
            case .onMemo:
                guard stone.status == .onMemo else { return false }
            default:
                guard stone.status != .sold else { return false }
            }

            if let type = stoneTypeFilter {
                guard stone.stoneType == type else { return false }
            }
            return true
        }
    }

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
        colorFilter != nil || clarityFilter != nil ||
        cutFilter != nil || labFilter != nil ||
        statusFilterGemstone != nil || originFilter != nil
    }

    var activeFilterCount: Int {
        var count = 0
        if stoneTypeFilter != nil { count += 1 }
        if shapeFilter != nil { count += 1 }
        if certifiedFilter != .any { count += 1 }
        if treatmentFilter != nil { count += 1 }
        if groupingFilter != nil { count += 1 }
        if caratMin != nil || caratMax != nil { count += 1 }
        if sellMin != nil || sellMax != nil { count += 1 }
        if colorFilter != nil { count += 1 }
        if clarityFilter != nil { count += 1 }
        if cutFilter != nil { count += 1 }
        if labFilter != nil { count += 1 }
        if statusFilterGemstone != nil { count += 1 }
        if originFilter != nil { count += 1 }
        return count
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
        // cutFilter, labFilter, statusFilterGemstone, originFilter not in pills (shown in filter bar)
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
        caratMinText = ""
        caratMaxText = ""
        sellMin = nil
        sellMax = nil
        sellMinText = ""
        sellMaxText = ""
        colorFilter = nil
        clarityFilter = nil
        cutFilter = nil
        labFilter = nil
        statusFilterGemstone = nil
        originFilter = nil
        searchText = ""
    }

    /// Filter gemstones by search and structured filters.
    /// Status, stone type, and mode are handled by the fetch predicate.
    func filtered(from gemstones: [Gemstone]) -> [Gemstone] {
        var result = gemstones

        // Free-text search (stays client-side — complex multi-field matching)
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

        // Status (additional client-side filter for gemstone status pills)
        if let s = statusFilterGemstone { result = result.filter { $0.status == s } }
        // Stone type — handled by predicate

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

        // Color filter
        if let c = colorFilter, !c.isEmpty {
            if c == "K+" {
                let early = ["D","E","F","G","H","I","J"]
                result = result.filter { !early.contains($0.color.uppercased()) }
            } else {
                let color = c.uppercased()
                result = result.filter { $0.color.uppercased().contains(color) }
            }
        }
        // Clarity filter
        if let c = clarityFilter, !c.isEmpty {
            if c == "I1+" {
                let better = ["IF","VVS1","VVS2","VS1","VS2","SI1","SI2"]
                result = result.filter { !better.contains($0.clarity.uppercased()) }
            } else {
                let clarity = c.lowercased()
                result = result.filter { $0.clarity.lowercased().contains(clarity) }
            }
        }

        // Cut
        if let c = cutFilter, !c.isEmpty {
            result = result.filter { $0.cut.lowercased() == c.lowercased() }
        }

        // Lab
        if let l = labFilter, !l.isEmpty {
            if l == "None" { result = result.filter { $0.certLab.isEmpty } }
            else { result = result.filter { $0.certLab.uppercased() == l.uppercased() } }
        }

        // Status (GemstoneStatus direct filter)
        if let s = statusFilterGemstone {
            result = result.filter { $0.status == s }
        }

        // Origin
        if let o = originFilter, !o.isEmpty {
            result = result.filter { $0.origin.lowercased().contains(o.lowercased()) }
        }

        return sorted(result)
    }

    // MARK: - Sorting

    private func sorted(_ stones: [Gemstone]) -> [Gemstone] {
        stones.sorted { a, b in
            let result: Bool
            switch sortKey {
            case "sku":
                result = a.sku.localizedCompare(b.sku) == .orderedAscending
            case "type":
                result = a.stoneType.rawValue.localizedCompare(b.stoneType.rawValue) == .orderedAscending
            case "shape":
                result = a.shape.localizedCompare(b.shape) == .orderedAscending
            case "carats":
                result = a.caratWeight < b.caratWeight
            case "price":
                result = a.sellPrice < b.sellPrice
            case "status":
                result = a.status.rawValue.localizedCompare(b.status.rawValue) == .orderedAscending
            case "dateAdded":
                result = a.createdAt < b.createdAt
            default:
                result = a.createdAt < b.createdAt
            }
            return sortAscending ? result : !result
        }
    }
}
