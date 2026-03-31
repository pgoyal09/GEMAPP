import SwiftUI
import SwiftData

/// Preview sheet shown after parsing a CSV file, before committing the import.
struct CSVImportPreviewSheet: View {
    let rows: [CSVImportService.ImportRow]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var importedCount: Int?
    @State private var errorMessage: String?
    @AccessibilityFocusState private var isTitleFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(AppColors.cardStroke)
            previewTable
            Divider().background(AppColors.cardStroke)
            footer
        }
        .frame(minWidth: 700, minHeight: 400)
        .appBackground()
        .onAppear { isTitleFocused = true }
    }

    private var header: some View {
        HStack {
            Text("CSV Import Preview")
                .font(AppTypography.heading)
                .foregroundStyle(AppColors.ink)
                .accessibilityFocused($isTitleFocused)
            Spacer()
            Text("\(rows.count) stone\(rows.count == 1 ? "" : "s") found")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.inkMuted)
        }
        .padding(AppSpacing.hero)
    }

    private var previewTable: some View {
        ScrollView([.horizontal, .vertical]) {
            LazyVStack(spacing: 0) {
                // Header
                HStack(spacing: 0) {
                    Text("Type").frame(width: 80, alignment: .leading)
                    Text("Carat").frame(width: 60, alignment: .trailing)
                    Text("Shape").frame(width: 80, alignment: .leading)
                    Text("Color").frame(width: 60, alignment: .leading)
                    Text("Clarity").frame(width: 60, alignment: .leading)
                    Text("Origin").frame(width: 80, alignment: .leading)
                    Text("Cost").frame(width: 80, alignment: .trailing)
                    Text("Sell").frame(width: 80, alignment: .trailing)
                    Text("Lab").frame(width: 60, alignment: .leading)
                }
                .font(AppTypography.caption.bold())
                .foregroundStyle(AppColors.inkMuted)
                .padding(.horizontal, AppSpacing.section)
                .padding(.vertical, AppSpacing.comfortable)

                Divider().background(AppColors.cardStroke)

                ForEach(rows) { row in
                    HStack(spacing: 0) {
                        Text(row.stoneType.rawValue).frame(width: 80, alignment: .leading)
                        Text(String(format: "%.2f", row.caratWeight)).frame(width: 60, alignment: .trailing)
                        Text(row.shape).frame(width: 80, alignment: .leading)
                        Text(row.color).frame(width: 60, alignment: .leading)
                        Text(row.clarity).frame(width: 60, alignment: .leading)
                        Text(row.origin).frame(width: 80, alignment: .leading)
                        Text(row.costPrice.asCurrency).frame(width: 80, alignment: .trailing)
                        Text(row.sellPrice.asCurrency).frame(width: 80, alignment: .trailing)
                        Text(row.certLab).frame(width: 60, alignment: .leading)
                    }
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.ink)
                    .padding(.horizontal, AppSpacing.section)
                    .padding(.vertical, AppSpacing.compact)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .glassTable()
        .padding(AppSpacing.section)
    }

    private var footer: some View {
        HStack {
            if let msg = errorMessage {
                Text(msg)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.danger)
            }
            if let count = importedCount {
                Text("Imported \(count) stone\(count == 1 ? "" : "s") successfully.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.success)
            }
            Spacer()
            Button("Cancel") { dismiss() }
                .buttonStyle(.outline)
                .keyboardShortcut(.escape, modifiers: [])
            Button("Import \(rows.count) Stones") {
                performImport()
            }.buttonStyle(.gradient)
            .disabled(importedCount != nil)
            .accessibilityHint("Double tap to import stones from CSV file")
        }
        .padding(AppSpacing.hero)
    }

    private func performImport() {
        let count = CSVImportService.importRows(rows, modelContext: modelContext)
        importedCount = count
        NotificationCenter.default.post(name: .dataStoreDidChange, object: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() }
    }
}
