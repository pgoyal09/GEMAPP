import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

/// RFID reconciliation view comparing scanned tags against expected inventory.
struct ReconcileView: View {
    @Bindable var viewModel: ReconcileViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var showExportSuccess = false

    var body: some View {
        VStack(spacing: 0) {
            controlBar
            progressBar

            ScrollView {
                VStack(spacing: AppSpacing.hero) {
                    missingSection
                    foundSection
                    extraSection
                }
                .padding(AppSpacing.hero)
            }
        }
        .onAppear {
            viewModel.load(modelContext: modelContext)
            viewModel.attachScanHandler()
        }
        .onDisappear {
            viewModel.detachScanHandler()
        }
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        VStack(alignment: .trailing, spacing: AppSpacing.standard) {
            HStack(spacing: AppSpacing.comfortable) {
                Text("RFID Reconciliation")
                    .font(AppTypography.heading)
                    .foregroundStyle(AppColors.ink)

                if let lastDate = viewModel.lastReconciliationDate {
                    Text("Last reconciled: \(lastDate.formatted(.dateTime.month().day().hour().minute()))")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.inkSubtle)
                }

                Spacer()

                if viewModel.isScanning {
                    HStack(spacing: AppSpacing.standard) {
                        ProgressView()
                            .controlSize(.small)
                            .tint(AppColors.primary)
                        Text("Scanning...")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.primary)
                    }
                }

                // Manual mode toggle
                Toggle("Manual Mode", isOn: $viewModel.isManualMode)
                    .toggleStyle(.switch)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.inkMuted)
                    .help("Check off stones physically without RFID scanning")

                if !viewModel.isManualMode {
                    if viewModel.isScanning {
                        Button {
                            viewModel.stopScanning()
                        } label: {
                            Label("Stop", systemImage: "stop.fill")
                        }
                        .buttonStyle(.outline(AppColors.danger))
                    } else {
                        Button("Start Scan", systemImage: "antenna.radiowaves.left.and.right") {
                            viewModel.startScanning()
                        }.buttonStyle(.gradient)
                    }
                }

                Button {
                    exportReconciliationReport()
                } label: {
                    Label("Export Report", systemImage: "arrow.down.doc")
                }
                .buttonStyle(.outline)
                .disabled(viewModel.foundStones.isEmpty && viewModel.missingStones.isEmpty)

                Button {
                    viewModel.resetScan()
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.outline)
            }
        }
        .padding(.horizontal, AppSpacing.hero)
        .padding(.vertical, AppSpacing.section)
        .overlay {
            if showExportSuccess {
                ToastOverlay(message: "Reconciliation report exported")
                    .animation(.easeInOut, value: showExportSuccess)
            }
        }
    }

    private func exportReconciliationReport() {
        let csv = viewModel.exportReconciliationReport()
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "reconciliation_report.csv"
        panel.allowedContentTypes = [UTType.commaSeparatedText]
        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    try csv.write(to: url, atomically: true, encoding: .utf8)
                    showExportSuccess = true
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(2))
                        showExportSuccess = false
                    }
                } catch {
                    AppLogger.data.error("Failed to export reconciliation report: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Progress

    private var progressBar: some View {
        let total = viewModel.availableStones.count
        let found = viewModel.foundStones.count
        let progress = total > 0 ? Double(found) / Double(total) : 0

        return VStack(spacing: AppSpacing.compact) {
            HStack {
                Text("\(found) of \(total) stones found")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.inkMuted)
                Spacer()
                Text(String(format: "%.0f%%", progress * 100))
                    .font(AppTypography.mono)
                    .foregroundStyle(AppColors.primary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: AppCornerRadius.small, style: .continuous)
                        .fill(AppColors.cardElevated)
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: AppCornerRadius.small, style: .continuous)
                        .fill(AppColors.primaryGradient)
                        .frame(width: geo.size.width * progress, height: 6)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, AppSpacing.hero)
        .padding(.bottom, AppSpacing.comfortable)
    }

    // MARK: - Missing Section (Amber)

    private var missingSection: some View {
        reconcileSection(
            title: "Missing",
            count: viewModel.missingStones.count,
            tone: .warning,
            isEmpty: viewModel.missingStones.isEmpty,
            emptyMessage: "All stones accounted for"
        ) {
            ForEach(viewModel.missingStones, id: \.persistentModelID) { stone in
                HStack(spacing: AppSpacing.comfortable) {
                    if viewModel.isManualMode {
                        Button {
                            viewModel.toggleManualVerification(for: stone)
                        } label: {
                            Image(systemName: "circle")
                                .font(AppTypography.body)
                                .foregroundStyle(AppColors.inkSubtle)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Mark \(stone.sku) as verified")
                    } else {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.warning)
                    }
                    Text(stone.sku)
                        .font(AppTypography.mono)
                        .foregroundStyle(AppColors.ink)
                    StoneTypeBadge(type: stone.stoneType.rawValue)
                    Spacer()
                    Text(String(format: "%.2f ct", stone.caratWeight))
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.inkMuted)
                    Text(stone.rfidEpc ?? "No tag")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.inkSubtle)
                }
                .padding(.vertical, AppSpacing.compact)
            }
        }
    }

    // MARK: - Found Section (Green)

    private var foundSection: some View {
        reconcileSection(
            title: "Found",
            count: viewModel.foundStones.count,
            tone: .success,
            isEmpty: viewModel.foundStones.isEmpty,
            emptyMessage: "No stones scanned yet"
        ) {
            ForEach(viewModel.foundStones, id: \.persistentModelID) { stone in
                HStack(spacing: AppSpacing.comfortable) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.success)
                    Text(stone.sku)
                        .font(AppTypography.mono)
                        .foregroundStyle(AppColors.ink)
                    StoneTypeBadge(type: stone.stoneType.rawValue)
                    Spacer()
                    Text(String(format: "%.2f ct", stone.caratWeight))
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.inkMuted)
                }
                .padding(.vertical, AppSpacing.compact)
            }
        }
    }

    // MARK: - Extra Section (Red)

    private var extraSection: some View {
        let extras = viewModel.extraScans
        return reconcileSection(
            title: "Extra",
            count: extras.count,
            tone: .danger,
            isEmpty: extras.isEmpty,
            emptyMessage: "No unexpected tags"
        ) {
            ForEach(extras, id: \.tagID) { scan in
                HStack(spacing: AppSpacing.comfortable) {
                    Image(systemName: "questionmark.circle.fill")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.danger)
                    Text(scan.tagID)
                        .font(AppTypography.mono)
                        .foregroundStyle(AppColors.ink)
                        .lineLimit(1)
                    Spacer()
                    Text(scan.reason)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.inkMuted)
                }
                .padding(.vertical, AppSpacing.compact)
            }
        }
    }

    // MARK: - Reusable Section

    private func reconcileSection<Content: View>(
        title: String,
        count: Int,
        tone: StatusBadge.Tone,
        isEmpty: Bool,
        emptyMessage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        GlassCard(padding: AppSpacing.section) {
            VStack(alignment: .leading, spacing: AppSpacing.comfortable) {
                HStack {
                    SectionHeader(title: title)
                    StatusBadge(title: "\(count)", tone: tone)
                    Spacer()
                }

                if isEmpty {
                    Text(emptyMessage)
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.inkSubtle)
                        .padding(.vertical, AppSpacing.comfortable)
                } else {
                    content()
                }
            }
        }
    }
}
