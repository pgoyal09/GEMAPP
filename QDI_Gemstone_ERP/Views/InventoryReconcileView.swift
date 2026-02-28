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
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                
                HStack(spacing: 12) {
                    Button(viewModel.isScanning ? "Stop Scan" : "Start Scan") {
                        if viewModel.isScanning {
                            viewModel.stopScanning()
                        } else {
                            viewModel.startScanning()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(viewModel.isScanning ? AppColors.accent : AppColors.primary)
                    
                    Button("Reset") {
                        viewModel.resetScan()
                    }
                }
                
                if viewModel.isScanning {
                    Label("Listening for tags…", systemImage: "antenna.radiowaves.left.and.right")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                HStack(alignment: .top, spacing: 20) {
                    // Missing: .available but NOT scanned (Pastel Red)
                    listCard(
                        title: "Missing (\(viewModel.missingStones.count))",
                        subtitle: "In safe but not scanned",
                        color: AppColors.accent,
                        rows: viewModel.missingStones.map { stone in
                            RowContent(sku: stone.sku, detail: "\(stone.stoneType.rawValue) · \(stone.displayCarats) ct")
                        }
                    )
                    
                    // Found: .available and scanned (Pastel Blue)
                    listCard(
                        title: "Found (\(viewModel.foundStones.count))",
                        subtitle: "Scanned and matched",
                        color: AppColors.primary,
                        rows: viewModel.foundStones.map { stone in
                            RowContent(sku: stone.sku, detail: "\(stone.stoneType.rawValue) · \(stone.displayCarats) ct")
                        }
                    )
                    
                    // Extra: scanned but not in DB or sold (Pastel Red)
                    listCard(
                        title: "Extra (\(viewModel.extraScans.count))",
                        subtitle: "Not in DB or not available",
                        color: AppColors.accent,
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
                .font(.headline)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
            if rows.isEmpty {
                Text("None")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 8)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(rows, id: \.sku) { row in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.sku)
                                    .font(.system(.body, design: .monospaced))
                                Text(row.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(color.opacity(0.25))
                        }
                    }
                }
                .frame(height: min(CGFloat(rows.count) * 44 + 20, 320))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.98))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.5), lineWidth: 1)
        )
    }
}

private struct RowContent {
    let sku: String
    let detail: String
}

private extension Gemstone {
    var displayCarats: String { String(format: "%.2f", caratWeight) }
}
