import SwiftUI
import SwiftData

struct ScannerView: View {
    @Bindable var viewModel: ScannerViewModel
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.l) {
                statusCard
                resultMessage
                infoCardsRow
                activityLog
            }
            .padding(AppSpacing.l)
        }
        .onAppear {
            viewModel.modelContext = modelContext
            viewModel.attachScanHandler()
        }
        .onDisappear { viewModel.detachScanHandler() }
    }

    // MARK: - Status

    private var statusCard: some View {
        GlassCard(padding: AppSpacing.l) {
            HStack(spacing: AppSpacing.m) {
                ZStack {
                    Circle()
                        .fill(viewModel.isScanning ? AppColors.success.opacity(0.2) : Color.white.opacity(0.06))
                        .frame(width: 48, height: 48)
                    Circle()
                        .fill(viewModel.isScanning ? AppColors.success : AppColors.inkSubtle)
                        .frame(width: 12, height: 12)
                }
                .accessibilityLabel(viewModel.isScanning ? "Scanner Active" : "Scanner Idle")
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.isScanning ? "Scanning Active" : "Scanner Idle")
                        .font(AppTypography.subheading)
                        .foregroundStyle(AppColors.ink)
                    Text("RFID tag scanner")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.inkSubtle)
                }
                Spacer()
                if viewModel.isScanning {
                    Button("Stop") { viewModel.stopScanning() }
                        .buttonStyle(.outline(AppColors.danger))
                        .accessibilityLabel("Stop Scanning")
                } else {
                    Button("Start Scanning") { viewModel.startScanning() }
                        .buttonStyle(.gradient)
                        .accessibilityLabel("Start RFID Scanning")
                }
                Button("Clear") { viewModel.clearDiscoveredTags() }
                    .buttonStyle(.outline)
                    .accessibilityLabel("Clear Scanned Tags")
            }
        }
    }

    // MARK: - Result

    @ViewBuilder
    private var resultMessage: some View {
        if let result = viewModel.lastProcessResult {
            GlassCard(padding: AppSpacing.m) {
                Text(result)
                    .font(AppTypography.body)
                    .foregroundStyle(result.contains("Failed") || result.contains("sold") ? AppColors.danger : AppColors.success)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Info Cards

    private var infoCardsRow: some View {
        HStack(spacing: AppSpacing.m) {
            GlassCard(padding: AppSpacing.m) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("LAST SCANNED EPC").font(AppTypography.caption).foregroundStyle(AppColors.inkSubtle).tracking(1)
                    Text(viewModel.lastDiscoveredTagID ?? "—")
                        .font(AppTypography.mono)
                        .foregroundStyle(AppColors.ink)
                        .textSelection(.enabled)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GlassCard(padding: AppSpacing.m) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("TOTAL EVENTS").font(AppTypography.caption).foregroundStyle(AppColors.inkSubtle).tracking(1)
                    Text("\(viewModel.discoveredTagIDs.count)")
                        .font(AppTypography.largeValue)
                        .foregroundStyle(AppColors.ink)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Activity Log

    private var activityLog: some View {
        GlassCard(padding: AppSpacing.m) {
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                SectionHeader(title: "Scanner Activity")
                if viewModel.discoveredTagIDs.isEmpty {
                    Text("No tags scanned yet.")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.inkSubtle)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(viewModel.discoveredTagIDs.reversed(), id: \.self) { tag in
                                HStack(spacing: 8) {
                                    Image(systemName: "wave.3.right")
                                        .font(.system(size: 10))
                                        .foregroundStyle(AppColors.primary)
                                        .accessibilityLabel("RFID Tag")
                                    Text(tag)
                                        .font(AppTypography.mono)
                                        .foregroundStyle(AppColors.inkMuted)
                                        .lineLimit(1)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                    .frame(maxHeight: 300)
                }
            }
        }
    }
}
