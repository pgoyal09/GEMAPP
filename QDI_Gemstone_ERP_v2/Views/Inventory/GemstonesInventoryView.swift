import SwiftUI
import SwiftData

struct GemstonesInventoryView: View {
    @Binding var navigateTo: NavigationItem

    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
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

    @State private var stoneTypeFilter: StoneType?
    @State private var colorFilter: String?
    @State private var originFilter: String?
    @State private var treatmentFilter: String?
    @State private var caratMin: Double?
    @State private var caratMax: Double?

    // MARK: - Filter Presets

    @State private var filterPresets: [FilterPreset] = FilterPresetStore.loadGemstonePresets()
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

    private var gemstones: [Gemstone] {
        allStones.filter { $0.stoneType != .diamond && $0.grouping != .lot && $0.status != .sold }
    }

    private var filteredStones: [Gemstone] {
        var result = gemstones
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            result = result.filter {
                $0.sku.lowercased().contains(q) ||
                $0.stoneType.rawValue.lowercased().contains(q) ||
                $0.color.lowercased().contains(q) ||
                $0.origin.lowercased().contains(q) ||
                $0.certNo.lowercased().contains(q)
            }
        }
        if let t = stoneTypeFilter { result = result.filter { $0.stoneType == t } }
        if let c = colorFilter, !c.isEmpty {
            let cl = c.lowercased()
            result = result.filter { $0.color.lowercased().contains(cl) || ($0.primaryColorVendor?.lowercased().contains(cl) == true) }
        }
        if let o = originFilter, !o.isEmpty {
            result = result.filter { $0.origin.lowercased().contains(o.lowercased()) }
        }
        if let t = treatmentFilter, !t.isEmpty {
            let tl = t.lowercased()
            if tl == "none" {
                result = result.filter { $0.treatment.isEmpty || $0.treatment.lowercased() == "none" }
            } else {
                result = result.filter { $0.treatment.lowercased().contains(tl) }
            }
        }
        if let min = caratMin { result = result.filter { $0.caratWeight >= min } }
        if let max = caratMax { result = result.filter { $0.caratWeight <= max } }
        return sortedStones(result)
    }

    private func sortedStones(_ stones: [Gemstone]) -> [Gemstone] {
        stones.sorted { a, b in
            let asc: Bool
            switch sortKey {
            case "type": asc = a.stoneType.rawValue.localizedCompare(b.stoneType.rawValue) == .orderedAscending
            case "carat": asc = a.caratWeight < b.caratWeight
            case "color": asc = a.color.localizedCompare(b.color) == .orderedAscending
            case "origin": asc = a.origin.localizedCompare(b.origin) == .orderedAscending
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
                .frame(width: 400)
                .background(AppColors.panelBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.large, style: .continuous))
                .shadow(color: .black.opacity(0.3), radius: 16, x: -4)
                .padding(.vertical, AppSpacing.section)
                .padding(.trailing, AppSpacing.section)
                .transition(reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity))
            }
        }
        .accessibilityIdentifier("GemstonesInventoryView")
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
            Text("Export \(exportableStones.count) gemstone\(exportableStones.count == 1 ? "" : "s") to RapNet CSV?")
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
            GlassSearchField(text: $searchText, placeholder: "Search by SKU, type, color, origin...", requestFocus: $searchFieldFocusRequest)
                .frame(maxWidth: 320)
            Spacer()
            treatmentFilterMenu
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
            Button("Export for RapNet") {
                showExportConfirm = true
            }
            .buttonStyle(.outline)
        }
        .padding(.horizontal, AppSpacing.hero)
        .padding(.vertical, AppSpacing.section)
        .alert("Save Filter Preset", isPresented: $showSavePreset) {
            TextField("Preset name", text: $newPresetName)
            Button("Save") { saveGemstonePreset() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter a name for this filter preset.")
        }
    }

    private var hasActiveFilters: Bool {
        stoneTypeFilter != nil || colorFilter != nil || originFilter != nil || treatmentFilter != nil || caratMin != nil || caratMax != nil
    }

    private var treatmentFilterMenu: some View {
        Menu {
            Button { treatmentFilter = nil } label: {
                HStack {
                    Text("All Treatments")
                    if treatmentFilter == nil { Image(systemName: "checkmark") }
                }
            }
            Divider()
            ForEach(["Heated", "Unheated", "Oiled", "None"], id: \.self) { treatment in
                Button {
                    treatmentFilter = treatment
                } label: {
                    HStack {
                        Text(treatment)
                        if treatmentFilter == treatment { Image(systemName: "checkmark") }
                    }
                }
            }
        } label: {
            Label(treatmentFilter ?? "Treatment", systemImage: "flask")
                .font(AppTypography.caption)
                .foregroundStyle(treatmentFilter != nil ? AppColors.primary : AppColors.inkMuted)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    @ViewBuilder
    private var filterPresetMenu: some View {
        if !filterPresets.isEmpty {
            Menu {
                ForEach(filterPresets) { preset in
                    Button(preset.name) { loadGemstonePreset(preset) }
                }
                Divider()
                Menu("Delete") {
                    ForEach(filterPresets) { preset in
                        Button(preset.name, role: .destructive) { deleteGemstonePreset(preset) }
                    }
                }
            } label: {
                Label("Presets", systemImage: "line.3.horizontal.decrease.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }

    private func saveGemstonePreset() {
        let name = newPresetName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let preset = FilterPreset(
            name: name,
            colorFilter: colorFilter,
            stoneTypeFilter: stoneTypeFilter?.rawValue,
            originFilter: originFilter,
            treatmentFilter: treatmentFilter,
            caratMin: caratMin,
            caratMax: caratMax
        )
        filterPresets.append(preset)
        FilterPresetStore.saveGemstonePresets(filterPresets)
        toastIsError = false
        withAnimation(reduceMotion ? nil : .default) { toastMessage = "Preset '\(name)' saved" }
    }

    private func loadGemstonePreset(_ preset: FilterPreset) {
        stoneTypeFilter = preset.stoneTypeFilter.flatMap { StoneType(rawValue: $0) }
        colorFilter = preset.colorFilter
        originFilter = preset.originFilter
        treatmentFilter = preset.treatmentFilter
        caratMin = preset.caratMin
        caratMax = preset.caratMax
    }

    private func deleteGemstonePreset(_ preset: FilterPreset) {
        filterPresets.removeAll { $0.id == preset.id }
        FilterPresetStore.saveGemstonePresets(filterPresets)
    }

    // MARK: - Filter Chips

    @ViewBuilder
    private var filterChips: some View {
        let hasFilters = stoneTypeFilter != nil || colorFilter != nil || originFilter != nil || treatmentFilter != nil || caratMin != nil || caratMax != nil
        if hasFilters {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.standard) {
                    if let t = stoneTypeFilter {
                        chipButton(t.rawValue) { stoneTypeFilter = nil }
                    }
                    if let c = colorFilter {
                        chipButton("Color: \(c)") { colorFilter = nil }
                    }
                    if let o = originFilter {
                        chipButton("Origin: \(o)") { originFilter = nil }
                    }
                    if let t = treatmentFilter {
                        chipButton("Treatment: \(t)") { treatmentFilter = nil }
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
                .padding(.horizontal, AppSpacing.hero).padding(.bottom, AppSpacing.comfortable)
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
        stoneTypeFilter = nil; colorFilter = nil; originFilter = nil; treatmentFilter = nil; caratMin = nil; caratMax = nil
    }

    // MARK: - Table

    private var tableContent: some View {
        VStack(spacing: 0) {
            tableHeader
            Divider().background(AppColors.cardStroke)
            if filteredStones.isEmpty {
                EmptyStateView(icon: "aqi.medium", title: "No gemstones found", subtitle: "Try adjusting your search or filters")
                    .frame(maxWidth: .infinity)
            } else {
                ScrollView(.vertical) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(filteredStones.enumerated()), id: \.element.persistentModelID) { index, stone in
                                stoneRow(stone)
                                    .simultaneousGesture(TapGesture(count: 2).onEnded {
                                        detailSheetStone = stone
                                    })
                                    .staggeredRow(index: index, reduceMotion: reduceMotion)
                            }
                        }
                        .padding(.vertical, AppSpacing.standard)
                        .frame(minWidth: 1100)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .glassTable()
        .padding(.horizontal, AppSpacing.hero)
        .padding(.bottom, AppSpacing.comfortable)
    }

    private var tableHeader: some View {
        HStack(spacing: 4) {
            sortableHeader("SKU", key: "sku", width: TableColumn.sku, alignment: .leading)
            sortableHeader("Type", key: "type", width: TableColumn.type, alignment: .leading)
            TableHeader(title: "Shape", width: TableColumn.shape, alignment: .leading)
            sortableHeader("Carat", key: "carat", width: TableColumn.carat, alignment: .trailing)
            sortableHeader("Color", key: "color", width: TableColumn.color, alignment: .leading)
            TableHeader(title: "Clarity", width: TableColumn.clarity, alignment: .leading)
            sortableHeader("Origin", key: "origin", width: TableColumn.origin, alignment: .leading)
            TableHeader(title: "Treatment", width: TableColumn.origin, alignment: .leading)
            TableHeader(title: "Lab", width: 50, alignment: .leading)
            TableHeader(title: "Cert #", width: 90, alignment: .leading)
            sortableHeader("Ask $/ct", key: "price", width: TableColumn.price, alignment: .trailing)
            sortableHeader("Cost $/ct", key: "cost", width: TableColumn.price, alignment: .trailing)
            TableHeader(title: "Margin %", width: TableColumn.margin, alignment: .trailing)
            sortableHeader("Status", key: "status", width: TableColumn.status, alignment: .center)
            Spacer()
        }
        .padding(.horizontal, AppSpacing.section)
        .padding(.vertical, AppSpacing.comfortable)
    }

    private func sortableHeader(_ title: String, key: String, width: CGFloat, alignment: Alignment) -> TableHeader {
        TableHeader(title: title, width: width, alignment: alignment, isSorted: sortKey == key, ascending: sortAscending, onTap: { toggleSort(key) })
    }

    @State private var detailSheetStone: Gemstone?

    private func stoneRow(_ stone: Gemstone) -> some View {
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

            highlightedText(stone.sku, highlight: searchText).font(AppTypography.mono).foregroundStyle(AppColors.ink).lineLimit(1).frame(width: TableColumn.sku, alignment: .leading)
            StoneTypeBadge(type: stone.stoneType.rawValue).frame(width: TableColumn.type, alignment: .leading)
            Text(stone.shape).font(AppTypography.body).foregroundStyle(AppColors.ink).lineLimit(1).frame(width: TableColumn.shape, alignment: .leading)
            Text(String(format: "%.2f", stone.caratWeight)).font(AppTypography.mono).foregroundStyle(AppColors.ink).frame(width: TableColumn.carat, alignment: .trailing)
            Text(stone.primaryColorVendor ?? stone.color).font(AppTypography.body).foregroundStyle(AppColors.ink).lineLimit(1).frame(width: TableColumn.color, alignment: .leading)
            Text(stone.clarity).font(AppTypography.body).foregroundStyle(AppColors.ink).lineLimit(1).frame(width: TableColumn.clarity, alignment: .leading)
            Text(stone.origin).font(AppTypography.body).foregroundStyle(AppColors.ink).lineLimit(1).frame(width: TableColumn.origin, alignment: .leading)
            Text(stone.treatment).font(AppTypography.body).foregroundStyle(AppColors.inkMuted).lineLimit(1).frame(width: TableColumn.origin, alignment: .leading)
            Text(stone.certLab).font(AppTypography.body).foregroundStyle(AppColors.ink).lineLimit(1).frame(width: 50, alignment: .leading)
            Text(stone.certNo).font(AppTypography.mono).foregroundStyle(AppColors.inkMuted).lineLimit(1).frame(width: 90, alignment: .leading)
            Text(stone.sellPrice.asCurrency).font(AppTypography.mono).foregroundStyle(AppColors.ink).frame(width: TableColumn.price, alignment: .trailing)
            Text(stone.costPrice.asCurrency).font(AppTypography.mono).foregroundStyle(AppColors.inkMuted).frame(width: TableColumn.price, alignment: .trailing)
            Text(marginText(cost: stone.costPrice, sell: stone.sellPrice)).font(AppTypography.mono).foregroundStyle(AppColors.inkMuted).frame(width: TableColumn.margin, alignment: .trailing)
            statusBadge(for: stone.status).frame(width: TableColumn.status, alignment: .center)
            Spacer()
        }
    }

    // MARK: - Summary

    private var summaryFooter: some View {
        let stones = filteredStones
        let totalCarats = stones.reduce(0.0) { $0 + $1.caratWeight }
        let totalValue = stones.reduce(Decimal.zero) { $0 + $1.sellPrice * Decimal($1.caratWeight) }
        return HStack(spacing: AppSpacing.hero) {
            Text("\(stones.count) gemstone\(stones.count == 1 ? "" : "s")")
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
            openWindow(id: "memo", value: memo.persistentModelID)
        } catch {
            toastIsError = true; withAnimation(reduceMotion ? nil : .default) { toastMessage = "Failed: \(ErrorMapper.userMessage(from: error))" }
        }
    }

    private func createInvoice() {
        let stones = filteredStones.filter { selectedStones.contains($0.persistentModelID) }
        guard !stones.isEmpty else { return }
        do {
            let inv = try TransactionService.createInvoice(modelContext: modelContext)
            for s in stones { try TransactionService.addStone(s, to: inv, modelContext: modelContext) }
            selectedStones.removeAll()
            openWindow(id: "invoice", value: inv.persistentModelID)
        } catch {
            toastIsError = true; withAnimation(reduceMotion ? nil : .default) { toastMessage = "Failed: \(ErrorMapper.userMessage(from: error))" }
        }
    }

    private func exportSelectedCSV() {
        let stones = filteredStones.filter { selectedStones.contains($0.persistentModelID) }
        guard !stones.isEmpty else { return }
        let csv = RapNetExportService.exportGemstoneCSV(stones: stones)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "selected-gemstones-\(Date().formatted(.dateTime.year().month(.twoDigits).day(.twoDigits))).csv"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try csv.write(to: url, atomically: true, encoding: .utf8)
                toastIsError = false; withAnimation(reduceMotion ? nil : .default) { toastMessage = "Exported \(stones.count) gemstones" }
            } catch {
                toastIsError = true; withAnimation(reduceMotion ? nil : .default) { toastMessage = "Export failed: \(ErrorMapper.userMessage(from: error))" }
            }
        }
    }

    private func performExport() {
        let csv = RapNetExportService.exportGemstoneCSV(stones: exportableStones)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        let dateStr = Date().formatted(.dateTime.year().month(.twoDigits).day(.twoDigits))
        panel.nameFieldStringValue = "rapnet-gemstones-\(dateStr).csv"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try csv.write(to: url, atomically: true, encoding: .utf8)
                toastIsError = false; withAnimation(reduceMotion ? nil : .default) { toastMessage = "Exported \(exportableStones.count) gemstones" }
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
        let allVisible = gemstones
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
