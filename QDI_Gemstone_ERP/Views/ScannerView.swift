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
            HeroCard {
                HStack {
                    HStack(spacing: AppSpacing.m) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(
                                    viewModel.isScanning
                                        ? LinearGradient(colors: [AppColors.success, Color(red: 0.10, green: 0.65, blue: 0.45)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                        : LinearGradient(colors: [AppColors.warning, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .frame(width: 40, height: 40)
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.white)
                        }
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text("RFID Scanner")
                                .font(AppTypography.title)
                                .foregroundStyle(AppColors.ink)
                            AppStatusBadge(
                                title: viewModel.isScanning ? "Active scan" : "Paused",
                                tone: viewModel.isScanning ? .success : .warning
                            )
                        }
                    }
                    Spacer()
                    HStack(spacing: AppSpacing.s) {
                        if viewModel.isScanning {
                            Button {
                                viewModel.stopScanning()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "stop.fill")
                                        .font(.system(size: 13, weight: .medium))
                                    Text("Stop Scanning")
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(AppColors.danger, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .shadow(color: AppColors.danger.opacity(0.20), radius: 8, y: 4)
                            }
                            .buttonStyle(.plain)
                        } else {
                            GradientButton(title: "Start Scanning", icon: "play.fill") {
                                viewModel.startScanning()
                            }
                        }

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
                GlassCard(padding: AppSpacing.m) {
                    Text(result)
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.inkMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.m) {
                GlassCard(padding: AppSpacing.m) {
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        Text("LAST SCANNED EPC")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.35))
                            .tracking(1.2)
                        Text(viewModel.lastDiscoveredTagID ?? "Waiting for scan…")
                            .font(AppTypography.mono)
                            .foregroundStyle(AppColors.ink)
                            .textSelection(.enabled)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GlassCard(padding: AppSpacing.m) {
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        Text("TOTAL EVENTS")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.35))
                            .tracking(1.2)
                        Text("\(viewModel.discoveredTagIDs.count)")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(AppColors.primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            GlassCard(padding: AppSpacing.m) {
                VStack(alignment: .leading, spacing: AppSpacing.m) {
                    HStack {
                        Text("SCANNER ACTIVITY")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.50))
                            .tracking(1.5)
                        Spacer()
                        AppStatusBadge(title: "\(viewModel.discoveredTagIDs.count) events", tone: .neutral)
                    }

                    if viewModel.discoveredTagIDs.isEmpty {
                        Text("No scans yet. Keep a tag in read range to begin.")
                            .font(AppTypography.body)
                            .foregroundStyle(AppColors.inkSubtle)
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
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
                                    .overlay(alignment: .bottom) {
                                        Divider().background(Color.white.opacity(0.04))
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 260)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(AppSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppColors.shellGradient)
        .onAppear { viewModel.attachScanHandler() }
        .onDisappear { viewModel.detachScanHandler() }
    }
}
