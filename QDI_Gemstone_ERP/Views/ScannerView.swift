import SwiftUI
import SwiftData

/// Scanner UI: displays state and actions from ScannerViewModel only. No business logic.
struct ScannerView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: ScannerViewModel

    init(viewModel: ScannerViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.l) {
            AppSurfaceCard(accent: viewModel.isScanning ? AppColors.success : AppColors.warning) {
                HStack {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("RFID Scanner")
                            .font(AppTypography.title)
                            .foregroundStyle(AppColors.ink)
                        AppStatusBadge(
                            title: viewModel.isScanning ? "Active scan" : "Paused",
                            tone: viewModel.isScanning ? .success : .warning
                        )
                    }
                    Spacer()
                    HStack(spacing: AppSpacing.s) {
                        Button(viewModel.isScanning ? "Stop Scanning" : "Start Scanning") {
                            if viewModel.isScanning {
                                viewModel.stopScanning()
                            } else {
                                viewModel.startScanning()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(viewModel.isScanning ? AppColors.danger : AppColors.primary)

                        if let tagID = viewModel.lastDiscoveredTagID {
                            Button("Process Tag") {
                                viewModel.processScannedTag(tagID: tagID, modelContext: modelContext)
                            }
                            .buttonStyle(.bordered)
                        }

                        if !viewModel.discoveredTagIDs.isEmpty {
                            Button("Clear") { viewModel.clearDiscoveredTags() }
                                .buttonStyle(.bordered)
                        }
                    }
                }
            }

            if let result = viewModel.lastProcessResult {
                AppSurfaceCard {
                    Text(result)
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.inkMuted)
                }
            }

            AppSurfaceCard {
                Text("Last scanned EPC")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.inkSubtle)
                Text(viewModel.lastDiscoveredTagID ?? "Waiting for scan…")
                    .font(AppTypography.mono)
                    .foregroundStyle(AppColors.ink)
                    .textSelection(.enabled)
                    .lineLimit(2)
            }

            AppSurfaceCard {
                HStack {
                    Text("Scanner Activity")
                        .font(AppTypography.heading)
                        .foregroundStyle(AppColors.ink)
                    Spacer()
                    AppStatusBadge(title: "\(viewModel.discoveredTagIDs.count) events", tone: .neutral)
                }

                if viewModel.discoveredTagIDs.isEmpty {
                    Text("No scans yet. Keep a tag in read range to begin.")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.inkSubtle)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: AppSpacing.s) {
                            ForEach(Array(viewModel.discoveredTagIDs.enumerated().reversed()), id: \.offset) { _, tag in
                                HStack {
                                    Circle()
                                        .fill(AppColors.primary.opacity(0.5))
                                        .frame(width: 8, height: 8)
                                    Text(tag)
                                        .font(AppTypography.mono)
                                        .foregroundStyle(AppColors.ink)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                .padding(.vertical, AppSpacing.xs)
                            }
                        }
                    }
                    .frame(maxHeight: 260)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(AppSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppColors.background)
        .onAppear { viewModel.attachScanHandler() }
        .onDisappear { viewModel.detachScanHandler() }
    }
}
