import SwiftUI
import SwiftData

struct DiamondsInventoryView: View {
    // MARK: - Table Layout

    private static let tableLayout = TableColumnLayout(columns: [
        ColumnDef("sku", weight: 2.0, minWidth: 80),
        ColumnDef("shape", weight: 1.5, minWidth: 60),
        ColumnDef("carat", weight: 1.2, minWidth: 55, alignment: .trailing),
        ColumnDef("color", weight: 1.5, minWidth: 60),
        ColumnDef("clarity", weight: 1.2, minWidth: 55),
        ColumnDef("cut", weight: 1.0, minWidth: 45),
        ColumnDef("polish", weight: 1.0, minWidth: 45),
        ColumnDef("sym", weight: 0.8, minWidth: 40),
        ColumnDef("fluor", weight: 1.0, minWidth: 45),
        ColumnDef("lab", weight: 0.8, minWidth: 40),
        ColumnDef("cert", weight: 1.5, minWidth: 65),
        ColumnDef("depth", weight: 1.0, minWidth: 50, alignment: .trailing),
        ColumnDef("table", weight: 1.0, minWidth: 50, alignment: .trailing),
        ColumnDef("askPrice", weight: 1.5, minWidth: 70, alignment: .trailing),
        ColumnDef("costPrice", weight: 1.5, minWidth: 70, alignment: .trailing),
        ColumnDef("margin", weight: 1.2, minWidth: 60, alignment: .trailing),
        ColumnDef("rap", weight: 1.0, minWidth: 50, alignment: .trailing),
        ColumnDef("status", weight: 1.5, minWidth: 65, alignment: .center),
    ], spacing: 4)

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

    // MARK: - Filter Toggle

    @State private var showAdvancedFilters = false

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

    @State private var shapeFilter: String?
    @State private var colorFilter: String?
    @State private var clarityFilter: String?
    @State private var caratMin: Double?
    @State private var caratMax: Double?

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
        if let s = shapeFilter, !s.isEmpty {
            result = result.filter { $0.shape.lowercased().contains(s.lowercased()) }
        }
        if let c = colorFilter, !c.isEmpty {
            result = result.filter { $0.color.uppercased().contains(c.uppercased()) }
        }
        if let c = clarityFilter, !c.isEmpty {
            result = result.filter { $0.clarity.lowercased().contains(c.lowercased()) }
        }
        if let min = caratMin { result = result.filter { $0.caratWeight >= min } }
        if let max = caratMax { result = result.filter { $0.caratWeight <= max } }
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
                    filterChips
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
                .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.large, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppCornerRadius.large, style: .continuous)
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
        .sheet(isPresented: $showCSVImportPreview) {
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
            GlassSearchField(text: $searchText, placeholder: "Search by SKU, color, clarity...", requestFocus: $searchFieldFocusRequest)
                .frame(minWidth: 180, maxWidth: 320)

            Button {
                withAnimation { showAdvancedFilters.toggle() }
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.title3)
                        .foregroundStyle(showAdvancedFilters || hasActiveFilters ? AppColors.primary : AppColors.inkMuted)
                    if activeFilterCount > 0 {
                        Text("\(activeFilterCount)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 14, height: 14)
                            .background(Circle().fill(AppColors.primary))
                            .offset(x: 4, y: -4)
                    }
                }
            }
            .buttonStyle(.plain)

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
        .padding(.horizontal, AppSpacing.hero)
        .padding(.vertical, AppSpacing.section)
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
    }

    private func deleteDiamondPreset(_ preset: FilterPreset) {
        filterPresets.removeAll { $0.id == preset.id }
        FilterPresetStore.saveDiamondPresets(filterPresets)
    }

    // MARK: - Filter Chips

    @ViewBuilder
    private var filterChips: some View {
        let hasFilters = shapeFilter != nil || colorFilter != nil || clarityFilter != nil || caratMin != nil || caratMax != nil
        if hasFilters || showAdvancedFilters {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.standard) {
                    if let s = shapeFilter {
                        chipButton(s) { shapeFilter = nil }
                    }
                    if let c = colorFilter {
                        chipButton("Color \(c)") { colorFilter = nil }
                    }
                    if let c = clarityFilter {
                        chipButton("Clarity \(c)") { clarityFilter = nil }
                    }
                    if caratMin != nil || caratMax != nil {
                        let label = String(format: "%.1f–%.1f ct", caratMin ?? 0, caratMax ?? 99)
                        chipButton(label) { caratMin = nil; caratMax = nil }
                    }
                    Button { clearAllFilters() } label: {
                        Text("Clear all").font(AppTypography.caption).foregroundStyle(AppColors.danger)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, AppSpacing.hero)
                .padding(.bottom, AppSpacing.comfortable)
            }
        }
    }

    private func chipButton(_ label: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            Text(label).font(AppTypography.caption).foregroundStyle(AppColors.primary)
            Button(action: action) {
                Image(systemName: "xmark").font(AppTypography.sectionLabel.weight(.bold)).foregroundStyle(AppColors.primary.opacity(AppOpacity.strong))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(label) filter")
        }
        .padding(.horizontal, AppSpacing.standard).padding(.vertical, AppSpacing.compact)
        .background(RoundedRectangle(cornerRadius: AppCornerRadius.small, style: .continuous).fill(AppColors.primary.opacity(AppOpacity.muted)))
    }

    private func clearAllFilters() {
        shapeFilter = nil; colorFilter = nil; clarityFilter = nil; caratMin = nil; caratMax = nil
    }

    // MARK: - Table

    private var tableContent: some View {
        GeometryReader { geo in
            let fixedWidth: CGFloat = 24 // checkbox
            let widths = Self.tableLayout.widths(for: geo.size.width - 2 * AppSpacing.standard - fixedWidth)
            VStack(spacing: 0) {
                tableHeader(widths: widths)
                Divider().background(AppColors.cardStroke)
                if filteredStones.isEmpty {
                    EmptyStateView(icon: "sparkle", title: "No diamonds found", subtitle: "Try adjusting your search or filters")
                        .frame(maxWidth: .infinity)
                } else {
                    ScrollView(.vertical) {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(filteredStones.enumerated()), id: \.element.persistentModelID) { index, stone in
                                stoneRow(stone, widths: widths)
                                    .simultaneousGesture(TapGesture(count: 2).onEnded {
                                        detailSheetStone = stone
                                    })
                                    .staggeredRow(index: index, reduceMotion: reduceMotion)
                            }
                        }
                        .padding(.vertical, AppSpacing.standard)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .glassTable()
        .padding(.horizontal, AppSpacing.hero)
        .padding(.bottom, AppSpacing.comfortable)
    }

    private func tableHeader(widths: [CGFloat]) -> some View {
        HStack(spacing: 4) {
            Color.clear.frame(width: 24)
            sortableHeader("SKU", key: "sku", width: widths[0], alignment: .leading)
            sortableHeader("Shape", key: "shape", width: widths[1], alignment: .leading)
            sortableHeader("Carat", key: "carat", width: widths[2], alignment: .trailing)
            sortableHeader("Color", key: "color", width: widths[3], alignment: .leading)
            sortableHeader("Clarity", key: "clarity", width: widths[4], alignment: .leading)
            TableHeader(title: "Cut", width: widths[5], alignment: .leading)
            TableHeader(title: "Polish", width: widths[6], alignment: .leading)
            TableHeader(title: "Sym", width: widths[7], alignment: .leading)
            TableHeader(title: "Fluor", width: widths[8], alignment: .leading)
            TableHeader(title: "Lab", width: widths[9], alignment: .leading)
            TableHeader(title: "Cert #", width: widths[10], alignment: .leading)
            TableHeader(title: "Depth%", width: widths[11], alignment: .trailing)
            TableHeader(title: "Table%", width: widths[12], alignment: .trailing)
            sortableHeader("Ask $/ct", key: "price", width: widths[13], alignment: .trailing)
            sortableHeader("Cost $/ct", key: "cost", width: widths[14], alignment: .trailing)
            TableHeader(title: "Margin %", width: widths[15], alignment: .trailing)
            TableHeader(title: "% Rap", width: widths[16], alignment: .trailing)
            sortableHeader("Status", key: "status", width: widths[17], alignment: .center)
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
            Text(stone.polish).font(AppTypography.body).foregroundStyle(AppColors.ink).lineLimit(1).frame(width: widths[6], alignment: .leading)
            Text(stone.symmetry).font(AppTypography.body).foregroundStyle(AppColors.ink).lineLimit(1).frame(width: widths[7], alignment: .leading)
            Text(stone.fluorescenceIntensity ?? stone.fluorescence).font(AppTypography.body).foregroundStyle(AppColors.ink).lineLimit(1).frame(width: widths[8], alignment: .leading)
            Text(stone.certLab).font(AppTypography.body).foregroundStyle(AppColors.ink).lineLimit(1).frame(width: widths[9], alignment: .leading)
            Text(stone.certNo).font(AppTypography.mono).foregroundStyle(AppColors.inkMuted).lineLimit(1).frame(width: widths[10], alignment: .leading)
            Text(stone.depthPct.map { String(format: "%.1f", $0) } ?? "—").font(AppTypography.mono).foregroundStyle(AppColors.inkMuted).frame(width: widths[11], alignment: .trailing)
            Text(stone.tablePct.map { String(format: "%.0f", $0) } ?? "—").font(AppTypography.mono).foregroundStyle(AppColors.inkMuted).frame(width: widths[12], alignment: .trailing)
            Text(stone.sellPrice.asCurrency).font(AppTypography.mono).foregroundStyle(AppColors.ink).frame(width: widths[13], alignment: .trailing)
            Text(stone.costPrice.asCurrency).font(AppTypography.mono).foregroundStyle(AppColors.inkMuted).frame(width: widths[14], alignment: .trailing)
            Text(marginText(cost: stone.costPrice, sell: stone.sellPrice)).font(AppTypography.mono).foregroundStyle(AppColors.inkMuted).frame(width: widths[15], alignment: .trailing)
            Text(rapDiscountText(rapNet: stone.rapNetPrice, sell: stone.sellPrice)).font(AppTypography.mono).foregroundStyle(rapDiscountColor(rapNet: stone.rapNetPrice, sell: stone.sellPrice)).frame(width: widths[16], alignment: .trailing)
            statusBadge(for: stone.status).frame(width: widths[17], alignment: .center)
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
            RoundedRectangle(cornerRadius: AppCornerRadius.large, style: .continuous)
                .fill(AppColors.cardBackground)
                .overlay(RoundedRectangle(cornerRadius: AppCornerRadius.large, style: .continuous).strokeBorder(AppColors.primary.opacity(AppOpacity.medium), lineWidth: 1))
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
        case .atLab:        return StatusBadge(title: "At Lab", tone: .accent)
        case .reserved:     return StatusBadge(title: "Reserved", tone: .warning)
        case .inTransit:    return StatusBadge(title: "In Transit", tone: .accent)
        case .consignment:  return StatusBadge(title: "Consignment", tone: .neutral)
        }
    }
}
