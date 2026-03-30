import SwiftUI
import SwiftData

/// RFID reconciliation view comparing scanned tags against expected inventory.
struct ReconcileView: View {
    @Bindable var viewModel: ReconcileViewModel
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(spacing: 0) {
            controlBar
            progressBar

            ScrollView {
                VStack(spacing: AppSpacing.l) {
                    missingSection
                    foundSection
                    extraSection
                }
                .padding(AppSpacing.l)
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
        HStack(spacing: AppSpacing.s) {
            Text("RFID Reconciliation")
                .font(AppTypography.heading)
                .foregroundStyle(AppColors.ink)

            Spacer()

            if viewModel.isScanning {
                HStack(spacing: AppSpacing.xs) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(AppColors.primary)
                    Text("Scanning...")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.primary)
                }
            }

            if viewModel.isScanning {
                Button {
                    viewModel.stopScanning()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .buttonStyle(.outline(AppColors.danger))
            } else {
                GradientButton(title: "Start Scan", icon: "antenna.radiowaves.left.and.right") {
                    viewModel.startScanning()
                }
            }

            Button {
                viewModel.resetScan()
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.outline)
        }
        .padding(.horizontal, AppSpacing.l)
        .padding(.vertical, AppSpacing.m)
    }

    // MARK: - Progress

    private var progressBar: some View {
        let total = viewModel.availableStones.count
        let found = viewModel.foundStones.count
        let progress = total > 0 ? Double(found) / Double(total) : 0

        return VStack(spacing: AppSpacing.xxs) {
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
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(AppColors.primaryGradient)
                        .frame(width: geo.size.width * progress, height: 6)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, AppSpacing.l)
        .padding(.bottom, AppSpacing.s)
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
                HStack(spacing: AppSpacing.s) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.warning)
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
                .padding(.vertical, AppSpacing.xxs)
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
                HStack(spacing: AppSpacing.s) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
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
                .padding(.vertical, AppSpacing.xxs)
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
                HStack(spacing: AppSpacing.s) {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 12))
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
                .padding(.vertical, AppSpacing.xxs)
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
        GlassCard(padding: AppSpacing.m) {
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                HStack {
                    SectionHeader(title: title)
                    StatusBadge(title: "\(count)", tone: tone)
                    Spacer()
                }

                if isEmpty {
                    Text(emptyMessage)
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.inkSubtle)
                        .padding(.vertical, AppSpacing.s)
                } else {
                    content()
                }
            }
        }
    }
}
