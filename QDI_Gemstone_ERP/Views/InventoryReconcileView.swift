import SwiftUI
import SwiftData

/// Reconcile UI: displays lists from ReconcileViewModel only. No business logic (Section 10).
struct InventoryReconcileView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: ReconcileViewModel
    
    init(viewModel: ReconcileViewModel) {
        _viewModel = State(initialValue: viewModel)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Inventory Reconcile")
                    .font(AppTypography.title)
                    .foregroundStyle(AppColors.ink)
                
                HStack(spacing: 12) {
                    Button(viewModel.isScanning ? "Stop Scan" : "Start Scan") {
                        if viewModel.isScanning {
                            viewModel.stopScanning()
                        } else {
                            viewModel.startScanning()
                        }
                    }
                    .buttonStyle(GradientButtonStyle(gradient: viewModel.isScanning
                        ? LinearGradient(colors: [AppColors.danger, AppColors.danger.opacity(0.7)], startPoint: .leading, endPoint: .trailing)
                        : AppColors.primaryGradient))
                    
                    Button("Reset") {
                        viewModel.resetScan()
                    }
                    .buttonStyle(OutlineGlassButtonStyle())
                }
                
                if viewModel.isScanning {
                    Label("Listening for tags…", systemImage: "antenna.radiowaves.left.and.right")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.inkMuted)
                }
                
                HStack(alignment: .top, spacing: 20) {
                    listCard(
                        title: "Missing (\(viewModel.missingStones.count))",
                        subtitle: "In safe but not scanned",
                        color: AppColors.danger,
                        rows: viewModel.missingStones.map { stone in
                            RowContent(sku: stone.sku, detail: "\(stone.stoneType.rawValue) · \(stone.displayCarats) ct")
                        }
                    )
                    
                    listCard(
                        title: "Found (\(viewModel.foundStones.count))",
                        subtitle: "Scanned and matched",
                        color: AppColors.success,
                        rows: viewModel.foundStones.map { stone in
                            RowContent(sku: stone.sku, detail: "\(stone.stoneType.rawValue) · \(stone.displayCarats) ct")
                        }
                    )
                    
                    listCard(
                        title: "Extra (\(viewModel.extraScans.count))",
                        subtitle: "Not in DB or not available",
                        color: AppColors.warning,
                        rows: viewModel.extraScans.map { RowContent(sku: $0.tagID, detail: $0.reason) }
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer(minLength: 0)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background)
        .onAppear {
            viewModel.load(modelContext: modelContext)
            viewModel.attachScanHandler()
        }
        .onDisappear {
            viewModel.detachScanHandler()
        }
    }
    
    private func listCard(title: String, subtitle: String, color: Color, rows: [RowContent]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(AppTypography.heading)
                .foregroundStyle(AppColors.ink)
            Text(subtitle)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.inkMuted)
            if rows.isEmpty {
                Text("None")
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.inkSubtle)
                    .padding(.vertical, 8)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(rows, id: \.sku) { row in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.sku)
                                    .font(AppTypography.mono)
                                    .foregroundStyle(AppColors.ink)
                                Text(row.detail)
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.inkMuted)
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, AppSpacing.s)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(color.opacity(0.10))
                        }
                    }
                }
                .frame(height: min(CGFloat(rows.count) * 44 + 20, 320))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.heroCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.l, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppCornerRadius.l, style: .continuous)
                .strokeBorder(color.opacity(0.30), lineWidth: 1)
        )
        .shadow(color: color.opacity(0.08), radius: 8, y: 4)
    }
}

private struct RowContent {
    let sku: String
    let detail: String
}

private extension Gemstone {
    var displayCarats: String { String(format: "%.2f", caratWeight) }
}
