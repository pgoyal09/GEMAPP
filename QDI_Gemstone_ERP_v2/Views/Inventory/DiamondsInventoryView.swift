import SwiftUI
import SwiftData

struct DiamondsInventoryView: View {
    // MARK: - Table Layout

    // Core columns visible by default (11 columns — fits comfortably)
    private static let tableLayout = TableColumnLayout(columns: [
        ColumnDef("sku", weight: 2.0, minWidth: 75),
        ColumnDef("shape", weight: 1.5, minWidth: 55),
        ColumnDef("carat", weight: 1.0, minWidth: 50, alignment: .trailing),
        ColumnDef("color", weight: 0.8, minWidth: 40),
        ColumnDef("clarity", weight: 0.8, minWidth: 45),
        ColumnDef("cut", weight: 0.8, minWidth: 40),
        ColumnDef("lab", weight: 0.8, minWidth: 35),
        ColumnDef("cert", weight: 1.5, minWidth: 65),
        ColumnDef("askPrice", weight: 1.5, minWidth: 80, alignment: .trailing),
        ColumnDef("costPrice", weight: 1.5, minWidth: 80, alignment: .trailing),
        ColumnDef("rap", weight: 1.0, minWidth: 55, alignment: .trailing),
        ColumnDef("status", weight: 1.2, minWidth: 65, alignment: .center),
    ], spacing: AppSpacing.tableColumnGap)

    @Binding var navigateTo: NavigationItem

    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openDocumentTracker) private var openDocTracker
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Query private var allStones: [Gemstone]

    @State private var searchText = ""
    @State private var selectedStoneID: PersistentIdentifier?
    @State private var selectedStones: Set<PersistentIdentifier> = []
    @State private var showEditSheet = false
    @State private var editingStone: Gemstone?
    @State private var toastMessage: String?
    @State private var toastIsError = false
    @State private var showExportConfirm = false
    @State private var includeMemoStones = false
    @State private var showCSVImportPreview = false
    @State private var csvImportRows: [CSVImportService.ImportRow] = []
    @State private var csvImportError: String?

    // MARK: - Filter Toggle (removed — filters always visible)

    // MARK: - Search Focus

    @State private var searchFieldFocusRequest = false

    // MARK: - Bulk Edit

    @State private var bulkEditMode: BulkEditSheet.Mode?
    @State private var bulkUndoValues: [(PersistentIdentifier, GemstoneStatus?, Decimal?, Decimal?)] = []
    @State private var showBulkUndo = false

    // MARK: - Sort State

    @State private var sortKey: String = "sku"
    @State private var sortAscending: Bool = true

    // MARK: - Filter State

    @State private var statusFilter: GemstoneStatus?
    @State private var shapeFilter: String?
    @State private var groupingFilter: StoneGrouping?
    @State private var colorFilter: String?
    @State private var clarityFilter: String?
    @State private var cutFilter: String?
    @State private var labFilter: String?
    @State private var caratMin: Double?
    @State private var caratMax: Double?
    @State private var caratMinText: String = ""
    @State private var caratMaxText: String = ""
    @State private var priceMin: Decimal?
    @State private var priceMax: Decimal?
    @State private var priceMinText: String = ""
    @State private var priceMaxText: String = ""
    @State private var originFilter: String?
    @State private var treatmentFilter: String?
    @State private var stoneTypeFilter: StoneType?

    // MARK: - Filter Presets

    @State private var filterPresets: [FilterPreset] = FilterPresetStore.loadDiamondPresets()
    @State private var showSavePreset = false
    @State private var newPresetName = ""

    // MARK: - Init

    init(navigateTo: Binding<NavigationItem>) {
        self._navigateTo = navigateTo
        // SwiftData #Predicate does not support custom enum types as captured constants.
        // Fetch all and filter in computed property instead.
        _allStones = Query(sort: \Gemstone.createdAt, order: .reverse)
    }

    // MARK: - Computed

    private var diamonds: [Gemstone] {
        allStones.filter { $0.stoneType == .diamond && $0.grouping != .lot && $0.status != .sold }
    }

    private var filteredStones: [Gemstone] {
        var result = diamonds
        // Status
        if let s = statusFilter { result = result.filter { $0.status == s } }
        // Shape
        if let s = shapeFilter, !s.isEmpty {
            if s == "Other" {
                let top = ["round","cushion","oval","pear","emerald","princess","marquise"]
                result = result.filter { !top.contains($0.shape.lowercased()) }
            } else {
                result = result.filter { $0.shape.lowercased().contains(s.lowercased()) }
            }
        }
        // Grouping
        if let g = groupingFilter { result = result.filter { $0.grouping == g } }
        // Color
        if let c = colorFilter, !c.isEmpty {
            if c == "K+" {
                let early = ["D","E","F","G","H","I","J"]
                result = result.filter { !early.contains($0.color.uppercased()) }
            } else {
                result = result.filter { $0.color.uppercased() == c.uppercased() }
            }
        }
        // Clarity
        if let c = clarityFilter, !c.isEmpty {
            if c == "I1+" {
                let better = ["IF","VVS1","VVS2","VS1","VS2","SI1","SI2"]
                result = result.filter { !better.contains($0.clarity.uppercased()) }
            } else {
                result = result.filter { $0.clarity.uppercased() == c.uppercased() }
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
        // Carat range
        if let min = caratMin { result = result.filter { $0.caratWeight >= min } }
        if let max = caratMax { result = result.filter { $0.caratWeight <= max } }
        // Price range
        if let min = priceMin { result = result.filter { $0.sellPrice >= min } }
        if let max = priceMax { result = result.filter { $0.sellPrice <= max } }
        // Search
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            result = result.filter {
                $0.sku.lowercased().contains(q) ||
                $0.color.lowercased().contains(q) ||
                $0.clarity.lowercased().contains(q) ||
                $0.certNo.lowercased().contains(q) ||
                $0.shape.lowercased().contains(q)
            }
        }
        return sortedStones(result)
    }

    private func sortedStones(_ stones: [Gemstone]) -> [Gemstone] {
        stones.sorted { a, b in
            let asc: Bool
            switch sortKey {
            case "carat": asc = a.caratWeight < b.caratWeight
            case "color": asc = a.color.localizedCompare(b.color) == .orderedAscending
            case "clarity": asc = a.clarity.localizedCompare(b.clarity) == .orderedAscending
            case "shape": asc = a.shape.localizedCompare(b.shape) == .orderedAscending
            case "price": asc = a.sellPrice < b.sellPrice
            case "cost": asc = a.costPrice < b.costPrice
            case "status": asc = a.status.rawValue.localizedCompare(b.status.rawValue) == .orderedAscending
            default: asc = a.sku.localizedCompare(b.sku) == .orderedAscending
            }
            return sortAscending ? asc : !asc
        }
    }

    private func toggleSort(_ key: String) {
        if sortKey == key { sortAscending.toggle() }
        else { sortKey = key; sortAscending = true }
    }

    private var selectedStone: Gemstone? {
        guard let id = selectedStoneID else { return nil }
        return filteredStones.first { $0.persistentModelID == id }
    }

    private var exportableStones: [Gemstone] {
        var stones = filteredStones.filter { $0.status == .available }
        if includeMemoStones {
            stones += filteredStones.filter { $0.status == .onMemo }
        }
        return stones
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .trailing) {
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    topBar
                    filterBar
                    tableContent
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                summaryFooter
            }

            if let stone = selectedStone {
                Color.black.opacity(0.15)
                    .ignoresSafeArea()
                    .onTapGesture { selectedStoneID = nil }

                GemstoneDetailPanel(gemstone: stone, onEdit: {
                    editingStone = stone
                    showEditSheet = true
                })
                .frame(width: 380)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.4), radius: 20, x: -6)
                .padding(.vertical, AppSpacing.standard)
                .padding(.trailing, AppSpacing.standard)
                .transition(reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity))
            }
        }
        .accessibilityIdentifier("DiamondsInventoryView")
        .background {
            Button("") { searchFieldFocusRequest = true }
                .keyboardShortcut("f", modifiers: .command)
                .hidden()
        }
        .animation(reduceMotion ? nil : AppAnimation.sheetSpring, value: selectedStone?.persistentModelID)
        .overlay(alignment: .bottom) {
            if !selectedStones.isEmpty {
                multiSelectBar
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay {
            if let msg = toastMessage {
                ToastOverlay(message: msg, isError: toastIsError, undoAction: showBulkUndo ? { performBulkUndo() } : nil)
                    .onAppear {
                        let delay: Double = showBulkUndo ? 5 : 3
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            withAnimation(reduceMotion ? nil : .default) {
                                toastMessage = nil
                                showBulkUndo = false
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            if let stone = editingStone {
                StoneFormView(mode: .edit(stone))
            }
        }
        .sheet(item: $detailSheetStone) { stone in
            GemstoneDetailPanel(gemstone: stone, onEdit: {
                detailSheetStone = nil
                editingStone = stone
                showEditSheet = true
            })
            .frame(minWidth: 400, minHeight: 500)
        }
        .alert("Export for RapNet", isPresented: $showExportConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Export") { performExport() }
        } message: {
            Text("Export \(exportableStones.count) diamond\(exportableStones.count == 1 ? "" : "s") to RapNet CSV?")
        }
        .sheet(isPresented: $showCSVImportPreview, onDismiss: {
            csvImportRows = []  // Reset for next import
        }) {
            CSVImportPreviewSheet(rows: csvImportRows)
        }
        .alert("CSV Import Error", isPresented: .constant(csvImportError != nil)) {
            Button("OK") { csvImportError = nil }
        } message: {
            Text(csvImportError ?? "")
        }
        .sheet(item: $bulkEditMode) { mode in
            BulkEditSheet(mode: mode, stoneCount: selectedStones.count) { action in
                applyBulkEdit(action)
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: AppSpacing.comfortable) {
            Spacer(minLength: AppSpacing.comfortable)
            filterPresetMenu
            Button("Save Filter", systemImage: "square.and.arrow.down") {
                newPresetName = ""
                showSavePreset = true
            }
            .buttonStyle(.outline)
            .disabled(!hasActiveFilters)
            Button("Quick Intake", systemImage: "plus.circle.fill") {
                navigateTo = .quickIntake
            }.buttonStyle(.gradient)
            Toggle("Incl. Memo", isOn: $includeMemoStones)
                .toggleStyle(.checkbox)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.inkMuted)
            Button("Import CSV") { pickCSVFile() }
                .buttonStyle(.outline)
                .accessibilityHint("Double tap to import stones from CSV file")
            Button("Export for RapNet") {
                showExportConfirm = true
            }
            .buttonStyle(.outline)
        }
        .padding(.horizontal, AppSpacing.section)
        .padding(.vertical, AppSpacing.standard)
        .alert("Save Filter Preset", isPresented: $showSavePreset) {
            TextField("Preset name", text: $newPresetName)
            Button("Save") { saveDiamondPreset() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter a name for this filter preset.")
        }
    }

    private var hasActiveFilters: Bool {
        shapeFilter != nil || colorFilter != nil || clarityFilter != nil || caratMin != nil || caratMax != nil
    }

    private var activeFilterCount: Int {
        var count = 0
        if shapeFilter != nil { count += 1 }
        if colorFilter != nil { count += 1 }
        if clarityFilter != nil { count += 1 }
        if caratMin != nil || caratMax != nil { count += 1 }
        return count
    }

    @ViewBuilder
    private var filterPresetMenu: some View {
        if !filterPresets.isEmpty {
            Menu {
                ForEach(filterPresets) { preset in
                    Button(preset.name) { loadDiamondPreset(preset) }
                        .accessibilityHint("Double tap to apply this saved filter")
                }
                Divider()
                Menu("Delete") {
                    ForEach(filterPresets) { preset in
                        Button(preset.name, role: .destructive) { deleteDiamondPreset(preset) }
                    }
                }
            } label: {
                Label("Presets", systemImage: "line.3.horizontal.decrease.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }

    private func saveDiamondPreset() {
        let name = newPresetName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let preset = FilterPreset(
            name: name,
            shapeFilter: shapeFilter,
            colorFilter: colorFilter,
            clarityFilter: clarityFilter,
            caratMin: caratMin,
            caratMax: caratMax
        )
        // Note: cutFilter, labFilter, priceMin/Max saved separately if FilterPreset is extended
        filterPresets.append(preset)
        FilterPresetStore.saveDiamondPresets(filterPresets)
        toastIsError = false
        withAnimation(reduceMotion ? nil : .default) { toastMessage = "Preset '\(name)' saved" }
    }

    private func loadDiamondPreset(_ preset: FilterPreset) {
        shapeFilter = preset.shapeFilter
        colorFilter = preset.colorFilter
        clarityFilter = preset.clarityFilter
        caratMin = preset.caratMin
        caratMax = preset.caratMax
        caratMinText = preset.caratMin.map { String(format: "%.2f", $0) } ?? ""
        caratMaxText = preset.caratMax.map { String(format: "%.2f", $0) } ?? ""
    }

    private func deleteDiamondPreset(_ preset: FilterPreset) {
        filterPresets.removeAll { $0.id == preset.id }
        FilterPresetStore.saveDiamondPresets(filterPresets)
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        InventoryFilterBarV2(
            config: .diamonds,
            statusFilter: $statusFilter,
            shapeFilter: $shapeFilter,
            groupingFilter: $groupingFilter,
            colorFilter: $colorFilter,
            clarityFilter: $clarityFilter,
            cutFilter: $cutFilter,
            originFilter: $originFilter,
            treatmentFilter: $treatmentFilter,
            stoneTypeFilter: $stoneTypeFilter,
            caratMinText: $caratMinText,
            caratMaxText: $caratMaxText,
            priceMinText: $priceMinText,
            priceMaxText: $priceMaxText,
            labFilter: $labFilter,
            searchText: $searchText,
            searchFieldFocusRequest: $searchFieldFocusRequest,
            onClearAll: clearAllFilters
        )
        .onChange(of: caratMinText) { _, val in caratMin = Double(val) }
        .onChange(of: caratMaxText) { _, val in caratMax = Double(val) }
        .onChange(of: priceMinText) { _, val in priceMin = Decimal(string: val) }
        .onChange(of: priceMaxText) { _, val in priceMax = Decimal(string: val) }
    }

    private func clearAllFilters() {
        statusFilter = nil; shapeFilter = nil; groupingFilter = nil
        colorFilter = nil; clarityFilter = nil; cutFilter = nil
        labFilter = nil; caratMin = nil; caratMax = nil
        priceMin = nil; priceMax = nil
        caratMinText = ""; caratMaxText = ""
        priceMinText = ""; priceMaxText = ""
        searchText = ""
    }

    // MARK: - Table

    @State private var headerHeight: CGFloat = 0

    private var tableContent: some View {
        // Use overlay pattern to avoid GeometryReader vertical centering issues.
        // The glassTable background fills the space; header is pinned at top,
        // scroll content fills below it.
        VStack(spacing: 0) {
            GeometryReader { geo in
                let fixedWidth: CGFloat = 24
                let widths = Self.tableLayout.widths(for: geo.size.width - 2 * AppSpacing.standard - fixedWidth)
                VStack(spacing: 0) {
                    tableHeader(widths: widths)
                        .background(GeometryReader { hg in
                            Color.clear.onAppear { headerHeight = hg.size.height }
                        })
                    Divider().background(AppColors.cardStroke)
                    if filteredStones.isEmpty {
                        EmptyStateView(icon: "sparkle", title: "No diamonds found", subtitle: "Try adjusting your search or filters")
                            .frame(maxWidth: .infinity)
                            .frame(height: max(0, geo.size.height - headerHeight - 1))
                    } else {
                        ScrollView(.vertical) {
                            LazyVStack(spacing: AppSpacing.tight) {
                                ForEach(Array(filteredStones.enumerated()), id: \.element.persistentModelID) { index, stone in
                                    stoneRow(stone, widths: widths)
                                        .simultaneousGesture(TapGesture(count: 2).onEnded {
                                            detailSheetStone = stone
                                        })
                                        .staggeredRow(index: index, reduceMotion: reduceMotion)
                                }
                            }
                            .padding(.vertical, AppSpacing.compact)
                        }
                        .frame(height: max(0, geo.size.height - headerHeight - 1))
                    }
                }
            }
        }
        .glassTable()
        .padding(.horizontal, AppSpacing.standard)
        .padding(.bottom, AppSpacing.compact)
    }

    private func tableHeader(widths: [CGFloat]) -> some View {
        HStack(spacing: AppSpacing.tableColumnGap) {
            Color.clear.frame(width: 24)
            sortableHeader("SKU", key: "sku", width: widths[0], alignment: .leading)
            sortableHeader("Shape", key: "shape", width: widths[1], alignment: .leading)
            sortableHeader("Carat", key: "carat", width: widths[2], alignment: .trailing)
            sortableHeader("Color", key: "color", width: widths[3], alignment: .leading)
            sortableHeader("Clarity", key: "clarity", width: widths[4], alignment: .leading)
            TableHeader(title: "Cut", width: widths[5], alignment: .leading)
            TableHeader(title: "Lab", width: widths[6], alignment: .leading)
            TableHeader(title: "Cert #", width: widths[7], alignment: .leading)
            sortableHeader("Ask/ct", key: "price", width: widths[8], alignment: .trailing)
            sortableHeader("Cost/ct", key: "cost", width: widths[9], alignment: .trailing)
            TableHeader(title: "% Rap", width: widths[10], alignment: .trailing)
            sortableHeader("Status", key: "status", width: widths[11], alignment: .center)
        }
        .padding(.horizontal, AppSpacing.standard)
        .padding(.vertical, AppSpacing.compact)
    }

    private func sortableHeader(_ title: String, key: String, width: CGFloat, alignment: Alignment) -> TableHeader {
        TableHeader(title: title, width: width, alignment: alignment, isSorted: sortKey == key, ascending: sortAscending, onTap: { toggleSort(key) })
    }

    @State private var detailSheetStone: Gemstone?

    private func stoneRow(_ stone: Gemstone, widths: [CGFloat]) -> some View {
        HoverRow(isSelected: selectedStoneID == stone.persistentModelID, onTap: {
            selectedStoneID = selectedStoneID == stone.persistentModelID ? nil : stone.persistentModelID
        }) {
            Toggle(isOn: Binding(
                get: { selectedStones.contains(stone.persistentModelID) },
                set: { on in
                    if on { selectedStones.insert(stone.persistentModelID) }
                    else { selectedStones.remove(stone.persistentModelID) }
                }
            )) { EmptyView() }
            .toggleStyle(.checkbox).frame(width: 24)

            highlightedText(stone.sku, highlight: searchText).font(AppTypography.mono).foregroundStyle(AppColors.ink).lineLimit(1).frame(width: widths[0], alignment: .leading)
            Text(stone.shape).font(AppTypography.body).foregroundStyle(AppColors.ink).lineLimit(1).frame(width: widths[1], alignment: .leading)
            Text(String(format: "%.2f", stone.caratWeight)).font(AppTypography.mono).foregroundStyle(AppColors.ink).frame(width: widths[2], alignment: .trailing)
            Text(stone.color).font(AppTypography.body).foregroundStyle(AppColors.ink).lineLimit(1).frame(width: widths[3], alignment: .leading)
            Text(stone.clarity).font(AppTypography.body).foregroundStyle(AppColors.ink).lineLimit(1).frame(width: widths[4], alignment: .leading)
            Text(stone.cut).font(AppTypography.body).foregroundStyle(AppColors.ink).lineLimit(1).frame(width: widths[5], alignment: .leading)
            Text(stone.certLab).font(AppTypography.body).foregroundStyle(AppColors.ink).lineLimit(1).frame(width: widths[6], alignment: .leading)
            Text(stone.certNo).font(AppTypography.mono).foregroundStyle(AppColors.inkMuted).lineLimit(1).frame(width: widths[7], alignment: .leading)
            Text(stone.sellPrice.asCurrency(stone.currencyType)).font(AppTypography.mono).foregroundStyle(AppColors.ink).frame(width: widths[8], alignment: .trailing)
            Text(stone.costPrice.asCurrency(stone.currencyType)).font(AppTypography.mono).foregroundStyle(AppColors.inkMuted).frame(width: widths[9], alignment: .trailing)
            Text(rapDiscountText(rapNet: stone.rapNetPrice, sell: stone.sellPrice)).font(AppTypography.mono).foregroundStyle(rapDiscountColor(rapNet: stone.rapNetPrice, sell: stone.sellPrice)).frame(width: widths[10], alignment: .trailing)
            statusBadge(for: stone.status).frame(width: widths[11], alignment: .center)
        }
    }

    // MARK: - Summary Footer

    private var summaryFooter: some View {
        let stones = filteredStones
        let totalCarats = stones.reduce(0.0) { $0 + $1.caratWeight }
        let totalValue = stones.reduce(Decimal.zero) { $0 + $1.sellPrice * Decimal($1.caratWeight) }
        return HStack(spacing: AppSpacing.hero) {
            Text("\(stones.count) diamond\(stones.count == 1 ? "" : "s")")
                .font(AppTypography.caption.bold()).foregroundStyle(AppColors.ink)
            Text("Total: \(String(format: "%.2f", totalCarats)) ct")
                .font(AppTypography.caption).foregroundStyle(AppColors.inkMuted)
            Text("Value: \(totalValue.asCurrency)")
                .font(AppTypography.caption).foregroundStyle(AppColors.inkMuted)
            Spacer()
        }
        .padding(.horizontal, AppSpacing.hero).padding(.vertical, AppSpacing.comfortable)
        .background(AppColors.cardBackground)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppColors.cardStroke)
                .frame(height: 1)
        }
    }

    // MARK: - Multi-Select

    private var multiSelectBar: some View {
        HStack(spacing: AppSpacing.section) {
            Text("\(selectedStones.count) selected").font(AppTypography.body).foregroundStyle(AppColors.ink)
            Spacer()
            if selectedStones.count >= 2 {
                Button("Update Status", systemImage: "arrow.triangle.2.circlepath") { bulkEditMode = .updateStatus }.buttonStyle(.outline)
                Button("Update Price", systemImage: "dollarsign.circle") { bulkEditMode = .updatePrice }.buttonStyle(.outline)
                Button("Adjust Price %", systemImage: "percent") { bulkEditMode = .adjustPricePercent }.buttonStyle(.outline)
                Button("Move to Lot", systemImage: "shippingbox") { bulkEditMode = .moveToLot }.buttonStyle(.outline)
            }
            Button("Create Memo", systemImage: "doc.text") { createMemo() }.buttonStyle(.gradient)
            Button("Create Invoice", systemImage: "doc.text.fill") { createInvoice() }.buttonStyle(.gradient)
            Button { exportSelectedCSV() } label: {
                Label("Export CSV", systemImage: "square.and.arrow.up")
            }.buttonStyle(.outline)
            Button("Clear") { selectedStones.removeAll() }.buttonStyle(.outline)
        }
        .padding(.horizontal, AppSpacing.hero).padding(.vertical, AppSpacing.section)
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                .fill(AppColors.cardBackground)
                .overlay(RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous).strokeBorder(AppColors.primary.opacity(AppOpacity.medium), lineWidth: 1))
                .shadow(color: .black.opacity(AppOpacity.medium), radius: 12, y: -4)
        )
        .padding(.horizontal, AppSpacing.hero).padding(.bottom, AppSpacing.section)
    }

    // MARK: - Actions

    private func createMemo() {
        let stones = filteredStones.filter { selectedStones.contains($0.persistentModelID) }
        guard !stones.isEmpty else { return }
        do {
            let memo = try TransactionService.createMemo(modelContext: modelContext)
            for s in stones { try TransactionService.addStone(s, to: memo, modelContext: modelContext) }
            selectedStones.removeAll()
            guard !openDocTracker.isOpen(memoID: memo.persistentModelID) else { return }
            openWindow(id: "memo", value: memo.persistentModelID)
        } catch {
            toastIsError = true; withAnimation(reduceMotion ? nil : .default) { toastMessage = "Failed: \(ErrorMapper.userMessage(from: error))" }
        }
    }

    private func createInvoice() {
        let stones = filteredStones.filter { selectedStones.contains($0.persistentModelID) }
        guard !stones.isEmpty else { return }
        do {
            let invoice = try TransactionService.createInvoice(modelContext: modelContext)
            for s in stones { try TransactionService.addStone(s, to: invoice, modelContext: modelContext) }
            selectedStones.removeAll()
            guard !openDocTracker.isOpen(invoiceID: invoice.persistentModelID) else { return }
            openWindow(id: "invoice", value: invoice.persistentModelID)
        } catch {
            toastIsError = true; withAnimation(reduceMotion ? nil : .default) { toastMessage = "Failed: \(ErrorMapper.userMessage(from: error))" }
        }
    }

    private func exportSelectedCSV() {
        let stones = filteredStones.filter { selectedStones.contains($0.persistentModelID) }
        guard !stones.isEmpty else { return }
        let csv = RapNetExportService.exportDiamondCSV(stones: stones)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "selected-diamonds-\(Date().formatted(.dateTime.year().month(.twoDigits).day(.twoDigits))).csv"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try csv.write(to: url, atomically: true, encoding: .utf8)
                toastIsError = false; withAnimation(reduceMotion ? nil : .default) { toastMessage = "Exported \(stones.count) diamonds" }
            } catch {
                toastIsError = true; withAnimation(reduceMotion ? nil : .default) { toastMessage = "Export failed: \(ErrorMapper.userMessage(from: error))" }
            }
        }
    }

    private func performExport() {
        let csv = RapNetExportService.exportDiamondCSV(stones: exportableStones)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        let dateStr = Date().formatted(.dateTime.year().month(.twoDigits).day(.twoDigits))
        panel.nameFieldStringValue = "rapnet-diamonds-\(dateStr).csv"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try csv.write(to: url, atomically: true, encoding: .utf8)
                toastIsError = false; withAnimation(reduceMotion ? nil : .default) { toastMessage = "Exported \(exportableStones.count) diamonds" }
            } catch {
                toastIsError = true; withAnimation(reduceMotion ? nil : .default) { toastMessage = "Export failed: \(ErrorMapper.userMessage(from: error))" }
            }
        }
    }

    private func pickCSVFile() {
        let panel = NSOpenPanel()
        panel.title = "Import Supplier Price List"
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            csvImportRows = try CSVImportService.parse(url: url)
            showCSVImportPreview = true
        } catch {
            csvImportError = error.localizedDescription
        }
    }

    // MARK: - Bulk Edit

    private func applyBulkEdit(_ action: BulkEditAction) {
        let stones = filteredStones.filter { selectedStones.contains($0.persistentModelID) }
        guard !stones.isEmpty else { return }

        // Store previous values for undo
        bulkUndoValues = stones.map { ($0.persistentModelID, $0.status, $0.costPrice, $0.sellPrice) }

        switch action {
        case .setStatus(let status):
            for stone in stones { stone.status = status }
        case .setPrice(let field, let value):
            for stone in stones {
                switch field {
                case .costPrice: stone.costPrice = value
                case .sellPrice: stone.sellPrice = value
                }
            }
        case .moveToLot(let sku):
            for stone in stones {
                stone.grouping = .lot
                if stone.remainingCarats == nil {
                    stone.remainingCarats = stone.caratWeight
                }
            }
            // If a lot SKU is provided, update the SKU prefix
            if !sku.isEmpty {
                for (i, stone) in stones.enumerated() {
                    stone.sku = "\(sku)-\(String(format: "%03d", i + 1))"
                }
            }
        case .adjustPricePercent(let field, let percent):
            let multiplier = 1 + percent / 100
            for stone in stones {
                switch field {
                case .costPrice: stone.costPrice = stone.costPrice * multiplier
                case .sellPrice: stone.sellPrice = stone.sellPrice * multiplier
                }
            }
        }
        do {
            try modelContext.save()
            NotificationCenter.default.post(name: .gemstoneDidChange, object: nil)
            NotificationCenter.default.post(name: .dataStoreDidChange, object: nil)
            toastIsError = false
            showBulkUndo = true
            withAnimation(reduceMotion ? nil : .default) { toastMessage = "Updated \(stones.count) stone\(stones.count == 1 ? "" : "s")" }
            selectedStones.removeAll()
        } catch {
            toastIsError = true
            showBulkUndo = false
            withAnimation(reduceMotion ? nil : .default) { toastMessage = "Bulk edit failed: \(ErrorMapper.userMessage(from: error))" }
        }
    }

    private func performBulkUndo() {
        let allVisible = diamonds
        for (id, status, cost, sell) in bulkUndoValues {
            guard let stone = allVisible.first(where: { $0.persistentModelID == id }) else { continue }
            if let status { stone.status = status }
            if let cost { stone.costPrice = cost }
            if let sell { stone.sellPrice = sell }
        }
        do {
            try modelContext.save()
            NotificationCenter.default.post(name: .gemstoneDidChange, object: nil)
            NotificationCenter.default.post(name: .dataStoreDidChange, object: nil)
            bulkUndoValues = []
            showBulkUndo = false
            toastIsError = false
            withAnimation(reduceMotion ? nil : .default) { toastMessage = "Bulk edit undone" }
        } catch {
            toastIsError = true
            withAnimation(reduceMotion ? nil : .default) { toastMessage = "Undo failed: \(ErrorMapper.userMessage(from: error))" }
        }
    }

    // MARK: - Search Highlighting

    private func highlightedText(_ text: String, highlight: String) -> Text {
        guard !highlight.isEmpty,
              let range = text.range(of: highlight, options: .caseInsensitive) else {
            return Text(text)
        }
        let before = String(text[text.startIndex..<range.lowerBound])
        let match = String(text[range])
        let after = String(text[range.upperBound...])
        return Text(before) + Text(match).foregroundColor(AppColors.primary).bold() + Text(after)
    }

    // MARK: - Margin

    private func marginText(cost: Decimal, sell: Decimal) -> String {
        guard cost > 0 else { return "\u{2014}" }
        let margin = (sell - cost) / cost * 100
        let value = NSDecimalNumber(decimal: margin).doubleValue
        return String(format: "%.1f%%", value)
    }

    // MARK: - Rap Discount

    private func rapDiscountText(rapNet: Decimal?, sell: Decimal) -> String {
        guard let rap = rapNet, rap > 0, sell > 0 else { return "\u{2014}" }
        let discount = NSDecimalNumber(decimal: (sell / rap - 1) * 100).doubleValue
        return String(format: "%+.1f%%", discount)
    }

    private func rapDiscountColor(rapNet: Decimal?, sell: Decimal) -> Color {
        guard let rap = rapNet, rap > 0, sell > 0 else { return AppColors.inkMuted }
        let discount = NSDecimalNumber(decimal: (sell / rap - 1) * 100).doubleValue
        return discount >= 0 ? AppColors.success : AppColors.danger
    }

    // MARK: - Helpers

    private func statusBadge(for status: GemstoneStatus) -> StatusBadge {
        switch status {
        case .available:    return StatusBadge(title: "Available", tone: .success)
        case .onMemo:       return StatusBadge(title: "On Memo", tone: .warning)
        case .sold:         return StatusBadge(title: "Sold", tone: .accent)
        case .atLab:        return StatusBadge(title: "At Lab", tone: .info)
        case .reserved:     return StatusBadge(title: "Reserved", tone: .danger)
        case .inTransit:    return StatusBadge(title: "In Transit", tone: .violet)
        case .consignment:  return StatusBadge(title: "Consignment", tone: .neutral)
        }
    }
}
