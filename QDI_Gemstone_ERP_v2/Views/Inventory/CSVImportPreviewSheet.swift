import SwiftUI
import SwiftData

/// Preview sheet shown after parsing a CSV file, before committing the import.
struct CSVImportPreviewSheet: View {
    let rows: [CSVImportService.ImportRow]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var importedCount: Int?
    @State private var errorMessage: String?

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
    }

    private var header: some View {
        HStack {
            Text("CSV Import Preview")
                .font(AppTypography.heading)
                .foregroundStyle(AppColors.ink)
            Spacer()
            Text("\(rows.count) stone\(rows.count == 1 ? "" : "s") found")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.inkMuted)
        }
        .padding(AppSpacing.l)
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
                .padding(.horizontal, AppSpacing.m)
                .padding(.vertical, AppSpacing.s)

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
                    .padding(.horizontal, AppSpacing.m)
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .glassTable()
        .padding(AppSpacing.m)
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
            GradientButton(title: "Import \(rows.count) Stones") {
                performImport()
            }
            .disabled(importedCount != nil)
        }
        .padding(AppSpacing.l)
    }

    private func performImport() {
        let count = CSVImportService.importRows(rows, modelContext: modelContext)
        importedCount = count
        NotificationCenter.default.post(name: .dataStoreDidChange, object: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() }
    }
}
