import SwiftUI
import SwiftData

struct DiamondsInventoryView: View {
    @Binding var navigateTo: NavigationItem

    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow

    @Query(sort: \Gemstone.createdAt, order: .reverse) private var allStones: [Gemstone]

    @State private var searchText = ""
    @State private var selectedStoneID: PersistentIdentifier?
    @State private var selectedStones: Set<PersistentIdentifier> = []
    @State private var showEditSheet = false
    @State private var editingStone: Gemstone?
    @State private var toastMessage: String?
    @State private var toastIsError = false
    @State private var showExportConfirm = false
    @State private var includeMemoStones = false

    // MARK: - Filter State

    @State private var shapeFilter: String?
    @State private var colorFilter: String?
    @State private var clarityFilter: String?
    @State private var caratMin: Double?
    @State private var caratMax: Double?

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
        return result
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
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                topBar
                filterChips
                tableContent
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if let stone = selectedStone {
                Divider().background(AppColors.cardStroke)
                GemstoneDetailPanel(gemstone: stone, onEdit: {
                    editingStone = stone
                    showEditSheet = true
                })
                .frame(width: 296)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selectedStone?.persistentModelID)
        .overlay(alignment: .bottom) {
            if !selectedStones.isEmpty {
                multiSelectBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay {
            if let msg = toastMessage {
                ToastOverlay(message: msg, isError: toastIsError)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation { toastMessage = nil }
                        }
                    }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            if let stone = editingStone {
                StoneFormView(mode: .edit(stone))
            }
        }
        .alert("Export for RapNet", isPresented: $showExportConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Export") { performExport() }
        } message: {
            Text("Export \(exportableStones.count) diamond\(exportableStones.count == 1 ? "" : "s") to RapNet CSV?")
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: AppSpacing.s) {
            GlassSearchField(text: $searchText, placeholder: "Search by SKU, color, clarity...")
                .frame(maxWidth: 320)
            Spacer()
            GradientButton(title: "Quick Intake", icon: "plus.circle.fill") {
                navigateTo = .quickIntake
            }
            Button("Export for RapNet") {
                showExportConfirm = true
            }
            .buttonStyle(.outline)
        }
        .padding(.horizontal, AppSpacing.l)
        .padding(.vertical, AppSpacing.m)
    }

    // MARK: - Filter Chips

    @ViewBuilder
    private var filterChips: some View {
        let hasFilters = shapeFilter != nil || colorFilter != nil || clarityFilter != nil || caratMin != nil || caratMax != nil
        if hasFilters {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.xs) {
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
                .padding(.horizontal, AppSpacing.l)
                .padding(.bottom, AppSpacing.s)
            }
        }
    }

    private func chipButton(_ label: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            Text(label).font(AppTypography.caption).foregroundStyle(AppColors.primary)
            Button(action: action) {
                Image(systemName: "xmark").font(.system(size: 8, weight: .bold)).foregroundStyle(AppColors.primary.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(AppColors.primary.opacity(0.12)))
    }

    private func clearAllFilters() {
        shapeFilter = nil; colorFilter = nil; clarityFilter = nil; caratMin = nil; caratMax = nil
    }

    // MARK: - Table

    private var tableContent: some View {
        ScrollView([.horizontal, .vertical]) {
            LazyVStack(spacing: 0) {
                tableHeader
                Divider().background(AppColors.cardStroke)
                if filteredStones.isEmpty {
                    EmptyStateView(icon: "sparkle", title: "No diamonds found", subtitle: "Try adjusting your search or filters")
                } else {
                    LazyVStack(spacing: 2) {
                        ForEach(filteredStones, id: \.persistentModelID) { stone in
                            stoneRow(stone)
                        }
                    }
                    .padding(.vertical, AppSpacing.xs)
                    summaryFooter
                }
            }
            .frame(minWidth: 1200, maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .glassTable()
        .padding(.horizontal, AppSpacing.l)
        .padding(.bottom, AppSpacing.l)
    }

    private var tableHeader: some View {
        HStack(spacing: 0) {
            TableHeader(title: "SKU", width: TableColumn.sku, alignment: .leading)
            TableHeader(title: "Shape", width: TableColumn.shape, alignment: .leading)
            TableHeader(title: "Carat", width: TableColumn.carat, alignment: .trailing)
            TableHeader(title: "Color", width: TableColumn.color, alignment: .leading)
            TableHeader(title: "Clarity", width: TableColumn.clarity, alignment: .leading)
            TableHeader(title: "Cut", width: 60, alignment: .leading)
            TableHeader(title: "Polish", width: 60, alignment: .leading)
            TableHeader(title: "Sym", width: 50, alignment: .leading)
            TableHeader(title: "Fluor", width: 60, alignment: .leading)
            TableHeader(title: "Lab", width: 50, alignment: .leading)
            TableHeader(title: "Cert #", width: 90, alignment: .leading)
            TableHeader(title: "Depth%", width: TableColumn.percent, alignment: .trailing)
            TableHeader(title: "Table%", width: TableColumn.percent, alignment: .trailing)
            TableHeader(title: "Ask $/ct", width: TableColumn.price, alignment: .trailing)
            TableHeader(title: "Cost $/ct", width: TableColumn.price, alignment: .trailing)
            TableHeader(title: "Status", width: TableColumn.status, alignment: .center)
            Spacer()
        }
        .padding(.horizontal, AppSpacing.m)
        .padding(.vertical, AppSpacing.s)
    }

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

            Text(stone.sku).font(AppTypography.mono).foregroundStyle(AppColors.ink).lineLimit(1).frame(width: TableColumn.sku, alignment: .leading)
            Text(stone.shape).font(AppTypography.body).foregroundStyle(AppColors.ink).lineLimit(1).frame(width: TableColumn.shape, alignment: .leading)
            Text(String(format: "%.2f", stone.caratWeight)).font(AppTypography.mono).foregroundStyle(AppColors.ink).frame(width: TableColumn.carat, alignment: .trailing)
            Text(stone.color).font(AppTypography.body).foregroundStyle(AppColors.ink).lineLimit(1).frame(width: TableColumn.color, alignment: .leading)
            Text(stone.clarity).font(AppTypography.body).foregroundStyle(AppColors.ink).lineLimit(1).frame(width: TableColumn.clarity, alignment: .leading)
            Text(stone.cut).font(AppTypography.body).foregroundStyle(AppColors.ink).lineLimit(1).frame(width: 60, alignment: .leading)
            Text(stone.polish).font(AppTypography.body).foregroundStyle(AppColors.ink).lineLimit(1).frame(width: 60, alignment: .leading)
            Text(stone.symmetry).font(AppTypography.body).foregroundStyle(AppColors.ink).lineLimit(1).frame(width: 50, alignment: .leading)
            Text(stone.fluorescenceIntensity ?? stone.fluorescence).font(AppTypography.body).foregroundStyle(AppColors.ink).lineLimit(1).frame(width: 60, alignment: .leading)
            Text(stone.certLab).font(AppTypography.body).foregroundStyle(AppColors.ink).lineLimit(1).frame(width: 50, alignment: .leading)
            Text(stone.certNo).font(AppTypography.mono).foregroundStyle(AppColors.inkMuted).lineLimit(1).frame(width: 90, alignment: .leading)
            Text(stone.depthPct.map { String(format: "%.1f", $0) } ?? "—").font(AppTypography.mono).foregroundStyle(AppColors.inkMuted).frame(width: TableColumn.percent, alignment: .trailing)
            Text(stone.tablePct.map { String(format: "%.0f", $0) } ?? "—").font(AppTypography.mono).foregroundStyle(AppColors.inkMuted).frame(width: TableColumn.percent, alignment: .trailing)
            Text(stone.sellPrice.asCurrency).font(AppTypography.mono).foregroundStyle(AppColors.ink).frame(width: TableColumn.price, alignment: .trailing)
            Text(stone.costPrice.asCurrency).font(AppTypography.mono).foregroundStyle(AppColors.inkMuted).frame(width: TableColumn.price, alignment: .trailing)
            statusBadge(for: stone.status).frame(width: TableColumn.status, alignment: .center)
            Spacer()
        }
    }

    // MARK: - Summary Footer

    private var summaryFooter: some View {
        let stones = filteredStones
        let totalCarats = stones.reduce(0.0) { $0 + $1.caratWeight }
        let totalValue = stones.reduce(Decimal.zero) { $0 + $1.sellPrice * Decimal($1.caratWeight) }
        return HStack(spacing: AppSpacing.l) {
            Text("\(stones.count) diamond\(stones.count == 1 ? "" : "s")")
                .font(AppTypography.caption.bold()).foregroundStyle(AppColors.ink)
            Text("Total: \(String(format: "%.2f", totalCarats)) ct")
                .font(AppTypography.caption).foregroundStyle(AppColors.inkMuted)
            Text("Value: \(totalValue.asCurrency)")
                .font(AppTypography.caption).foregroundStyle(AppColors.inkMuted)
            Spacer()
        }
        .padding(.horizontal, AppSpacing.m).padding(.vertical, AppSpacing.s)
        .background(Color.white.opacity(0.03))
    }

    // MARK: - Multi-Select

    private var multiSelectBar: some View {
        HStack(spacing: AppSpacing.m) {
            Text("\(selectedStones.count) selected").font(AppTypography.body).foregroundStyle(AppColors.ink)
            Spacer()
            GradientButton(title: "Create Memo", icon: "doc.text") { createMemo() }
            GradientButton(title: "Create Invoice", icon: "doc.text.fill") { createInvoice() }
            Button("Clear") { selectedStones.removeAll() }.buttonStyle(.outline)
        }
        .padding(.horizontal, AppSpacing.l).padding(.vertical, AppSpacing.m)
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.m, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: AppCornerRadius.m, style: .continuous).strokeBorder(AppColors.primary.opacity(0.3), lineWidth: 1))
                .shadow(color: .black.opacity(0.3), radius: 12, y: -4)
        )
        .padding(.horizontal, AppSpacing.l).padding(.bottom, AppSpacing.m)
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
            toastIsError = true; withAnimation { toastMessage = "Failed: \(error.localizedDescription)" }
        }
    }

    private func createInvoice() {
        let stones = filteredStones.filter { selectedStones.contains($0.persistentModelID) }
        guard !stones.isEmpty else { return }
        do {
            let invoice = try TransactionService.createInvoice(modelContext: modelContext)
            for s in stones { try TransactionService.addStone(s, to: invoice, modelContext: modelContext) }
            selectedStones.removeAll()
            openWindow(id: "invoice", value: invoice.persistentModelID)
        } catch {
            toastIsError = true; withAnimation { toastMessage = "Failed: \(error.localizedDescription)" }
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
                toastIsError = false; withAnimation { toastMessage = "Exported \(exportableStones.count) diamonds" }
            } catch {
                toastIsError = true; withAnimation { toastMessage = "Export failed: \(error.localizedDescription)" }
            }
        }
    }

    // MARK: - Helpers

    private func statusBadge(for status: GemstoneStatus) -> StatusBadge {
        switch status {
        case .available: return StatusBadge(title: "Available", tone: .success)
        case .onMemo:    return StatusBadge(title: "On Memo", tone: .warning)
        case .sold:      return StatusBadge(title: "Sold", tone: .accent)
        }
    }
}
