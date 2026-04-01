import SwiftUI
import SwiftData

/// Tabular rapid-entry view for bulk stone intake.
/// Users can tab through minimal fields per row and save multiple stones at once.
struct QuickEntryView: View {
    /// Default stone type based on which inventory tab user came from.
    var defaultStoneType: StoneType = .diamond

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedCategory: StoneType = .diamond
    @State private var rows: [QuickEntryRow] = [QuickEntryRow()]
    @State private var toastMessage: String?
    @State private var toastIsError = false
    @FocusState private var focusedField: FieldFocus?

    // MARK: - Column Widths

    private enum Col {
        static let index: CGFloat = 30
        static let rowType: CGFloat = 110
        static let type: CGFloat = 100
        static let shape: CGFloat = 80
        static let carat: CGFloat = 70
        static let color: CGFloat = 60
        static let clarity: CGFloat = 60
        static let treatment: CGFloat = 80
        static let cost: CGFloat = 80
        static let sell: CGFloat = 80
        static let origin: CGFloat = 80
        static let certLab: CGFloat = 70
        static let certNo: CGFloat = 90
        static let pairID: CGFloat = 80
        static let lotID: CGFloat = 80
        static let pieces: CGFloat = 60
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider().background(AppColors.cardElevated)
            entryTable
        }
        .overlay {
            if let msg = toastMessage {
                ToastOverlay(message: msg, isError: toastIsError)
                    .animation(reduceMotion ? nil : AppAnimation.standard, value: toastMessage)
            }
        }
        .onAppear {
            selectedCategory = defaultStoneType
            rows = [QuickEntryRow(stoneType: defaultStoneType)]
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: AppSpacing.comfortable) {
            Text("Quick Entry")
                .font(AppTypography.heading)
                .foregroundStyle(AppColors.ink)

            Picker("Category", selection: $selectedCategory) {
                ForEach(StoneType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .frame(maxWidth: 300)
            .accessibilityLabel("Stone Type Category")
            .onChange(of: selectedCategory) { _, newType in
                for i in rows.indices { rows[i].stoneType = newType }
            }

            Text("\(rows.count) row\(rows.count == 1 ? "" : "s")")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.inkSubtle)
            Spacer()
            Button("Clear All") {
                rows = [QuickEntryRow(stoneType: selectedCategory)]
                focusedField = .type(rows[0].id)
            }
            .buttonStyle(.outline)
            .disabled(rows.count == 1 && rows[0].isEmpty)
            Button("Save All (\(validRowCount))", systemImage: "checkmark.circle.fill") {
                saveAll()
            }.buttonStyle(.gradient)
            .disabled(validRowCount == 0)
        }
        .padding(.horizontal, AppSpacing.hero)
        .padding(.vertical, AppSpacing.section)
    }

    // MARK: - Table

    private var entryTable: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                headerRow
                Divider().background(AppColors.cardStroke)
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    entryRow(index: index, row: row)
                    if index < rows.count - 1 {
                        Divider().background(AppColors.softHighlight)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .glassTable()
        .padding(AppSpacing.hero)
    }

    private var headerRow: some View {
        HStack(spacing: AppSpacing.standard) {
            Text("#").frame(width: Col.index, alignment: .center)
            Text("Row Type").frame(width: Col.rowType, alignment: .leading)
            Text("Type").frame(width: Col.type, alignment: .leading)
            Text("Shape").frame(width: Col.shape, alignment: .leading)
            Text("Carat").frame(width: Col.carat, alignment: .trailing)
            Text("Color").frame(width: Col.color, alignment: .leading)
            Text("Clarity").frame(width: Col.clarity, alignment: .leading)
            Text("Treatment").frame(width: Col.treatment, alignment: .leading)
            Text("Cost $").frame(width: Col.cost, alignment: .trailing)
            Text("Sell $").frame(width: Col.sell, alignment: .trailing)
            Text("Origin").frame(width: Col.origin, alignment: .leading)
            Text("Cert Lab").frame(width: Col.certLab, alignment: .leading)
            Text("Cert #").frame(width: Col.certNo, alignment: .leading)
            Spacer()
        }
        .font(AppTypography.caption.bold())
        .foregroundStyle(AppColors.inkMuted)
        .padding(.horizontal, AppSpacing.section)
        .padding(.vertical, AppSpacing.comfortable)
    }

    private func entryRow(index: Int, row: QuickEntryRow) -> some View {
        VStack(spacing: AppSpacing.compact) {
            HStack(spacing: AppSpacing.standard) {
                Text("\(index + 1)")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.inkSubtle)
                    .frame(width: Col.index, alignment: .center)

                Picker("", selection: binding(for: index, keyPath: \.rowType)) {
                    Text("Single").tag(RowType.single)
                    Text("Pair").tag(RowType.pair)
                    Text("Lot").tag(RowType.lot)
                }
                .labelsHidden()
                .frame(width: Col.rowType)

                Picker("", selection: binding(for: index, keyPath: \.stoneType)) {
                    ForEach(StoneType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .labelsHidden()
                .frame(width: Col.type)
                .focused($focusedField, equals: .type(row.id))

                TextField("", text: binding(for: index, keyPath: \.shape))
                    .frame(width: Col.shape)
                    .glassField()
                    .focused($focusedField, equals: .shape(row.id))

                TextField("", value: binding(for: index, keyPath: \.caratWeight), format: .number)
                    .frame(width: Col.carat)
                    .glassField()
                    .multilineTextAlignment(.trailing)
                    .focused($focusedField, equals: .carat(row.id))

                TextField("", text: binding(for: index, keyPath: \.color))
                    .frame(width: Col.color)
                    .glassField()
                    .focused($focusedField, equals: .color(row.id))

                TextField("", text: binding(for: index, keyPath: \.clarity))
                    .frame(width: Col.clarity)
                    .glassField()
                    .focused($focusedField, equals: .clarity(row.id))

                TextField("", text: binding(for: index, keyPath: \.treatment))
                    .frame(width: Col.treatment)
                    .glassField()
                    .focused($focusedField, equals: .treatment(row.id))

                TextField("", value: binding(for: index, keyPath: \.costPrice), format: .number)
                    .frame(width: Col.cost)
                    .glassField()
                    .multilineTextAlignment(.trailing)
                    .focused($focusedField, equals: .cost(row.id))

                TextField("", value: binding(for: index, keyPath: \.sellPrice), format: .number)
                    .frame(width: Col.sell)
                    .glassField()
                    .multilineTextAlignment(.trailing)
                    .focused($focusedField, equals: .sell(row.id))

                TextField("", text: binding(for: index, keyPath: \.origin))
                    .frame(width: Col.origin)
                    .glassField()
                    .focused($focusedField, equals: .origin(row.id))

                TextField("", text: binding(for: index, keyPath: \.certLab))
                    .frame(width: Col.certLab)
                    .glassField()
                    .focused($focusedField, equals: .certLab(row.id))

                TextField("", text: binding(for: index, keyPath: \.certNo))
                    .frame(width: Col.certNo)
                    .glassField()
                    .focused($focusedField, equals: .certNo(row.id))
                    .onSubmit { addRowIfNeeded(afterIndex: index) }

                Spacer()

                Button {
                    if rows.count > 1 { rows.remove(at: index) }
                } label: {
                    Image(systemName: "minus.circle")
                        .foregroundStyle(rows.count > 1 ? AppColors.danger : AppColors.inkSubtle)
                }
                .buttonStyle(.plain)
                .disabled(rows.count <= 1)
            }

            // Extra fields for Pair / Lot
            if row.rowType == .pair {
                HStack(spacing: AppSpacing.standard) {
                    Text("").frame(width: Col.index)
                    Text("Pair ID")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.inkMuted)
                        .frame(width: Col.rowType, alignment: .trailing)
                    TextField("Pair ID", text: binding(for: index, keyPath: \.pairID))
                        .frame(width: Col.type)
                        .glassField()
                    Spacer()
                }
                .padding(.leading, AppSpacing.standard)
            }

            if row.rowType == .lot {
                HStack(spacing: AppSpacing.standard) {
                    Text("").frame(width: Col.index)
                    Text("Lot ID")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.inkMuted)
                        .frame(width: Col.rowType, alignment: .trailing)
                    TextField("Lot ID", text: binding(for: index, keyPath: \.lotID))
                        .frame(width: Col.type)
                        .glassField()
                    Text("Pieces")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.inkMuted)
                    TextField("", value: binding(for: index, keyPath: \.pieces), format: .number)
                        .frame(width: Col.pieces)
                        .glassField()
                        .multilineTextAlignment(.trailing)
                    Spacer()
                }
                .padding(.leading, AppSpacing.standard)
            }
        }
        .padding(.horizontal, AppSpacing.section)
        .padding(.vertical, AppSpacing.standard)
    }

    // MARK: - Helpers

    private var validRowCount: Int {
        rows.filter { $0.isValid }.count
    }

    private func binding<T>(for index: Int, keyPath: WritableKeyPath<QuickEntryRow, T>) -> Binding<T> {
        Binding(
            get: { rows[index][keyPath: keyPath] },
            set: { rows[index][keyPath: keyPath] = $0 }
        )
    }

    private func addRowIfNeeded(afterIndex index: Int) {
        if index == rows.count - 1 {
            let newRow = QuickEntryRow(stoneType: selectedCategory)
            rows.append(newRow)
            focusedField = .type(newRow.id)
        } else {
            let nextRow = rows[index + 1]
            focusedField = .type(nextRow.id)
        }
    }

    private func saveAll() {
        let validRows = rows.filter { $0.isValid }
        guard !validRows.isEmpty else { return }

        var count = 0
        for row in validRows {
            let grouping: StoneGrouping
            switch row.rowType {
            case .single: grouping = .single
            case .pair: grouping = .pair
            case .lot: grouping = .lot
            }

            let sku = SKUGenerator.generate(
                type: row.stoneType,
                shape: row.shape,
                grouping: grouping,
                modelContext: modelContext
            )
            let stone = Gemstone(
                sku: sku,
                stoneType: row.stoneType,
                caratWeight: row.caratWeight,
                shape: row.shape,
                origin: row.origin,
                color: row.color,
                clarity: row.clarity,
                treatment: row.treatment,
                hasCert: !row.certLab.isEmpty,
                certLab: row.certLab,
                certNo: row.certNo,
                costPrice: row.costPrice,
                sellPrice: row.sellPrice
            )
            stone.grouping = grouping
            if grouping == .lot {
                stone.remainingCarats = row.caratWeight
                if row.pieces > 0 {
                    stone.numberOfStones = row.pieces
                }
            }
            modelContext.insert(stone)
            count += 1
        }

        NotificationCenter.default.post(name: .dataStoreDidChange, object: nil)

        toastIsError = false
        toastMessage = "Saved \(count) stone\(count == 1 ? "" : "s")"
        rows = [QuickEntryRow(stoneType: selectedCategory)]
        focusedField = .type(rows[0].id)

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(reduceMotion ? nil : .default) { toastMessage = nil }
        }
    }

    // MARK: - Focus

    private enum FieldFocus: Hashable {
        case type(UUID)
        case shape(UUID)
        case carat(UUID)
        case color(UUID)
        case clarity(UUID)
        case treatment(UUID)
        case cost(UUID)
        case sell(UUID)
        case origin(UUID)
        case certLab(UUID)
        case certNo(UUID)
    }
}

// MARK: - Row Type

private enum RowType: String, CaseIterable, Identifiable {
    case single = "Single"
    case pair = "Pair"
    case lot = "Lot"
    var id: String { rawValue }
}

// MARK: - Row Model

private struct QuickEntryRow: Identifiable {
    let id = UUID()
    var rowType: RowType = .single
    var stoneType: StoneType = .diamond
    var shape: String = ""
    var caratWeight: Double = 0
    var color: String = ""
    var clarity: String = ""
    var treatment: String = ""
    var costPrice: Decimal = 0
    var sellPrice: Decimal = 0
    var origin: String = ""
    var certLab: String = ""
    var certNo: String = ""
    var pairID: String = ""
    var lotID: String = ""
    var pieces: Int = 0

    var isEmpty: Bool {
        shape.isEmpty && caratWeight == 0 && color.isEmpty && clarity.isEmpty
    }

    var isValid: Bool {
        caratWeight > 0
    }
}
