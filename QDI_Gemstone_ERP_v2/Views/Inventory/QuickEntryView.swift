import SwiftUI
import SwiftData

/// Spreadsheet-style rapid-entry view for bulk stone intake.
/// Tab between fields, Enter to add a new row. Each row has a type selector (Single/Pair/Lot).
struct QuickEntryView: View {
    /// Default stone type based on which inventory tab user came from.
    var defaultStoneType: StoneType = .diamond

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.navigationGuard) private var navigationGuard
    @State private var selectedCategory: StoneType = .diamond
    @State private var isDirty = false
    @State private var rows: [QuickEntryRow] = [QuickEntryRow()]
    @State private var toastMessage: String?
    @State private var toastIsError = false
    @FocusState private var focusedField: FieldFocus?

    // MARK: - Column Widths

    private enum Col {
        static let index: CGFloat = 30
        static let rowType: CGFloat = 100
        static let type: CGFloat = 100
        static let shape: CGFloat = 80
        static let carat: CGFloat = 70
        static let color: CGFloat = 60
        static let clarity: CGFloat = 60
        static let cost: CGFloat = 80
        static let sell: CGFloat = 80
        static let origin: CGFloat = 80
        static let certLab: CGFloat = 70
        static let certNo: CGFloat = 90
        static let pieces: CGFloat = 60
        static let action: CGFloat = 28
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider().background(AppColors.cardStroke)
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
        .onChange(of: rows.map(\.caratWeight)) { _, _ in
            isDirty = rows.contains { !$0.isEmpty }
            navigationGuard.hasUnsavedChanges = isDirty
        }
        .onChange(of: rows.map(\.shape)) { _, _ in
            isDirty = rows.contains { !$0.isEmpty }
            navigationGuard.hasUnsavedChanges = isDirty
        }
        .onChange(of: rows.map(\.color)) { _, _ in
            isDirty = rows.contains { !$0.isEmpty }
            navigationGuard.hasUnsavedChanges = isDirty
        }
        .onChange(of: rows.map(\.clarity)) { _, _ in
            isDirty = rows.contains { !$0.isEmpty }
            navigationGuard.hasUnsavedChanges = isDirty
        }
        .onChange(of: rows.map(\.origin)) { _, _ in
            isDirty = rows.contains { !$0.isEmpty }
            navigationGuard.hasUnsavedChanges = isDirty
        }
        .onChange(of: rows.map(\.certLab)) { _, _ in
            isDirty = rows.contains { !$0.isEmpty }
            navigationGuard.hasUnsavedChanges = isDirty
        }
        .onChange(of: rows.map(\.certNo)) { _, _ in
            isDirty = rows.contains { !$0.isEmpty }
            navigationGuard.hasUnsavedChanges = isDirty
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
                focusedField = .shape(rows[0].id)
            }
            .buttonStyle(.outline)
            .disabled(rows.count == 1 && rows[0].isEmpty)

            Button("Save All (\(validRowCount))", systemImage: "checkmark.circle.fill") {
                saveAll()
            }
            .buttonStyle(.gradient)
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
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                .fill(AppColors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                .strokeBorder(AppColors.cardStroke, lineWidth: 1)
        )
        .padding(AppSpacing.hero)
    }

    // MARK: - Header Row

    private var headerRow: some View {
        HStack(spacing: AppSpacing.standard) {
            headerCell("#", width: Col.index, alignment: .center)
            headerCell("Row Type", width: Col.rowType)
            headerCell("Type", width: Col.type)
            headerCell("Shape", width: Col.shape)
            headerCell("Carat", width: Col.carat, alignment: .trailing)
            headerCell("Color", width: Col.color)
            headerCell("Clarity", width: Col.clarity)
            headerCell("Cost $", width: Col.cost, alignment: .trailing)
            headerCell("Sell $", width: Col.sell, alignment: .trailing)
            headerCell("Origin", width: Col.origin)
            headerCell("Cert Lab", width: Col.certLab)
            headerCell("Cert #", width: Col.certNo)
            Spacer()
        }
        .padding(.horizontal, AppSpacing.section)
        .padding(.vertical, AppSpacing.comfortable)
        .background(AppColors.panelBackground)
    }

    private func headerCell(_ title: String, width: CGFloat, alignment: Alignment = .leading) -> some View {
        Text(title)
            .font(AppTypography.caption.bold())
            .foregroundStyle(AppColors.inkMuted)
            .frame(width: width, alignment: alignment)
    }

    // MARK: - Data Row

    private func entryRow(index: Int, row: QuickEntryRow) -> some View {
        VStack(spacing: AppSpacing.compact) {
            HStack(spacing: AppSpacing.standard) {
                // Row number
                Text("\(index + 1)")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.inkSubtle)
                    .frame(width: Col.index, alignment: .center)

                // Row Type picker
                Picker("", selection: binding(for: index, keyPath: \.rowType)) {
                    Text("Single").tag(RowType.single)
                    Text("Pair").tag(RowType.pair)
                    Text("Lot").tag(RowType.lot)
                }
                .labelsHidden()
                .frame(width: Col.rowType)

                // Stone Type picker
                Picker("", selection: binding(for: index, keyPath: \.stoneType)) {
                    ForEach(StoneType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .labelsHidden()
                .frame(width: Col.type)

                // Shape
                AutocompleteTextField(text: binding(for: index, keyPath: \.shape), options: StoneShape.allNames, label: "Shape")
                    .frame(width: Col.shape)

                // Carat
                cellField(value: binding(for: index, keyPath: \.caratWeight), width: Col.carat, focus: .carat(row.id), trailing: true)

                // Color
                cellField(text: binding(for: index, keyPath: \.color), width: Col.color, focus: .color(row.id))

                // Clarity
                cellField(text: binding(for: index, keyPath: \.clarity), width: Col.clarity, focus: .clarity(row.id))

                // Cost
                cellField(value: binding(for: index, keyPath: \.costPrice), width: Col.cost, focus: .cost(row.id), trailing: true)

                // Sell
                cellField(value: binding(for: index, keyPath: \.sellPrice), width: Col.sell, focus: .sell(row.id), trailing: true)

                // Origin
                cellField(text: binding(for: index, keyPath: \.origin), width: Col.origin, focus: .origin(row.id))

                // Cert Lab
                cellField(text: binding(for: index, keyPath: \.certLab), width: Col.certLab, focus: .certLab(row.id))

                // Cert No — Enter adds new row
                cellField(text: binding(for: index, keyPath: \.certNo), width: Col.certNo, focus: .certNo(row.id))
                    .onSubmit { addRowIfNeeded(afterIndex: index) }

                Spacer()

                // Delete row button
                Button {
                    if rows.count > 1 { rows.remove(at: index) }
                } label: {
                    Image(systemName: "minus.circle")
                        .foregroundStyle(rows.count > 1 ? AppColors.danger : AppColors.inkSubtle)
                }
                .buttonStyle(.plain)
                .disabled(rows.count <= 1)
                .frame(width: Col.action)
            }

            // Extra fields for Lot rows
            if row.rowType == .lot {
                HStack(spacing: AppSpacing.standard) {
                    Text("").frame(width: Col.index)
                    Text("Pieces")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.inkMuted)
                        .frame(width: Col.rowType, alignment: .trailing)
                    cellField(value: binding(for: index, keyPath: \.pieces), width: Col.pieces, focus: .pieces(row.id), trailing: true)
                    Spacer()
                }
                .padding(.leading, AppSpacing.standard)
            }
        }
        .padding(.horizontal, AppSpacing.section)
        .padding(.vertical, AppSpacing.standard)
        .background(index % 2 == 0 ? Color.clear : AppColors.softHighlight)
    }

    // MARK: - Cell Field Builders

    private func cellField(text: Binding<String>, width: CGFloat, focus: FieldFocus) -> some View {
        TextField("", text: text)
            .textFieldStyle(.plain)
            .font(AppTypography.body)
            .padding(.horizontal, AppSpacing.compact)
            .frame(width: width, height: 28)
            .background(
                RoundedRectangle(cornerRadius: AppCornerRadius.field, style: .continuous)
                    .fill(AppColors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppCornerRadius.field, style: .continuous)
                    .strokeBorder(AppColors.cardStroke, lineWidth: 1)
            )
            .focused($focusedField, equals: focus)
    }

    private func cellField(value: Binding<Double>, width: CGFloat, focus: FieldFocus, trailing: Bool = false) -> some View {
        TextField("", value: value, format: .number)
            .textFieldStyle(.plain)
            .font(AppTypography.body)
            .padding(.horizontal, AppSpacing.compact)
            .frame(width: width, height: 28)
            .multilineTextAlignment(trailing ? .trailing : .leading)
            .background(
                RoundedRectangle(cornerRadius: AppCornerRadius.field, style: .continuous)
                    .fill(AppColors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppCornerRadius.field, style: .continuous)
                    .strokeBorder(AppColors.cardStroke, lineWidth: 1)
            )
            .focused($focusedField, equals: focus)
    }

    private func cellField(value: Binding<Decimal>, width: CGFloat, focus: FieldFocus, trailing: Bool = false) -> some View {
        TextField("", value: value, format: .number)
            .textFieldStyle(.plain)
            .font(AppTypography.body)
            .padding(.horizontal, AppSpacing.compact)
            .frame(width: width, height: 28)
            .multilineTextAlignment(trailing ? .trailing : .leading)
            .background(
                RoundedRectangle(cornerRadius: AppCornerRadius.field, style: .continuous)
                    .fill(AppColors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppCornerRadius.field, style: .continuous)
                    .strokeBorder(AppColors.cardStroke, lineWidth: 1)
            )
            .focused($focusedField, equals: focus)
    }

    private func cellField(value: Binding<Int>, width: CGFloat, focus: FieldFocus, trailing: Bool = false) -> some View {
        TextField("", value: value, format: .number)
            .textFieldStyle(.plain)
            .font(AppTypography.body)
            .padding(.horizontal, AppSpacing.compact)
            .frame(width: width, height: 28)
            .multilineTextAlignment(trailing ? .trailing : .leading)
            .background(
                RoundedRectangle(cornerRadius: AppCornerRadius.field, style: .continuous)
                    .fill(AppColors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppCornerRadius.field, style: .continuous)
                    .strokeBorder(AppColors.cardStroke, lineWidth: 1)
            )
            .focused($focusedField, equals: focus)
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
            focusedField = .shape(newRow.id)
        } else {
            let nextRow = rows[index + 1]
            focusedField = .shape(nextRow.id)
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
                treatment: "",
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

        isDirty = false
        navigationGuard.hasUnsavedChanges = false
        toastIsError = false
        toastMessage = "Saved \(count) stone\(count == 1 ? "" : "s")"
        rows = [QuickEntryRow(stoneType: selectedCategory)]
        focusedField = .shape(rows[0].id)

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(reduceMotion ? nil : .default) { toastMessage = nil }
        }
    }

    // MARK: - Focus

    private enum FieldFocus: Hashable {
        case shape(UUID)
        case carat(UUID)
        case color(UUID)
        case clarity(UUID)
        case cost(UUID)
        case sell(UUID)
        case origin(UUID)
        case certLab(UUID)
        case certNo(UUID)
        case pieces(UUID)
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
    var costPrice: Decimal = 0
    var sellPrice: Decimal = 0
    var origin: String = ""
    var certLab: String = ""
    var certNo: String = ""
    var pieces: Int = 0

    var isEmpty: Bool {
        shape.isEmpty && caratWeight == 0 && color.isEmpty && clarity.isEmpty
    }

    var isValid: Bool {
        caratWeight > 0
    }
}
