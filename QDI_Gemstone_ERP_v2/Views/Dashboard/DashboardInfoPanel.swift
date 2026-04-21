import SwiftUI

struct DashboardInfoPanel: View {
    let viewModel: DashboardViewModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openDocumentTracker) private var openDocTracker
    @AppStorage("memoAgingGreen") private var memoAgingGreen: Int = 7
    @AppStorage("memoAgingYellow") private var memoAgingYellow: Int = 14
    @AppStorage("memoAgingOrange") private var memoAgingOrange: Int = 30

    @State private var backupScheduler = BackupScheduler()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.hero) {
                oldestOpenMemosSection
                openMemosSummarySection
                if backupScheduler.isEnabled {
                    autoBackupSection
                }
            }
            .padding(AppSpacing.hero)
        }
        .frame(width: 296)
        .background(AppColors.panelBackground)
        .overlay(alignment: .leading) {
            Divider().background(AppColors.cardElevated)
        }
    }

    // MARK: - Oldest Open Memos

    private var oldestOpenMemosSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.standard) {
            SectionHeader(title: "Oldest Open Memos")
            if viewModel.overdueMemoCount > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.warningDeep)
                    Text("\(viewModel.overdueMemoCount) memo\(viewModel.overdueMemoCount == 1 ? "" : "s") over 60 days")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.warningDeep)
                }
                .padding(.horizontal, AppSpacing.standard)
                .padding(.vertical, AppSpacing.compact)
                .background(
                    RoundedRectangle(cornerRadius: AppCornerRadius.small, style: .continuous)
                        .fill(AppColors.warningDeep.opacity(AppOpacity.muted))
                )
            }
            if viewModel.oldestOpenMemos.isEmpty {
                Text("No open memos")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.inkSubtle)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.standard)
                    .background(
                        RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                            .fill(AppColors.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                                    .strokeBorder(AppColors.cardStroke, lineWidth: 1)
                            )
                    )
            } else {
                VStack(spacing: 0) {
                    ForEach(viewModel.oldestOpenMemos) { item in
                        Button {
                            guard !openDocTracker.isOpen(memoID: item.id) else { return }
                            openWindow(id: "memo", value: item.id)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("#\(item.referenceNumber)")
                                        .font(AppTypography.body.weight(.medium))
                                        .foregroundStyle(AppColors.inkMuted)
                                    Text(item.customerName)
                                        .font(AppTypography.caption)
                                        .foregroundStyle(AppColors.inkSubtle)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(item.ageDays)d")
                                        .font(AppTypography.caption)
                                        .foregroundStyle(agingColor(days: item.ageDays))
                                    Text(item.openAmount.asCurrency)
                                        .font(AppTypography.caption)
                                        .foregroundStyle(AppColors.inkMuted)
                                }
                            }
                            .padding(.vertical, AppSpacing.standard)
                            .padding(.horizontal, AppSpacing.comfortable)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                        .fill(AppColors.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                                .strokeBorder(AppColors.cardStroke, lineWidth: 1)
                        )
                )
            }
        }
    }

    // MARK: - Open Memos Summary

    private var openMemosSummarySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.standard) {
            SectionHeader(title: "Open Memos")
            HStack(spacing: AppSpacing.standard) {
                snapshotChip("Count", viewModel.totalOpenMemoCount, color: AppColors.primary)
                VStack(spacing: 2) {
                    Text(viewModel.totalValueOnMemo.asCurrency)
                        .font(AppTypography.largeValue.monospacedDigit())
                        .foregroundStyle(AppColors.warning)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("TOTAL VALUE")
                        .font(AppTypography.sectionLabel)
                        .foregroundStyle(AppColors.inkSubtle)
                        .tracking(0.5)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.standard)
                .background(
                    RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                        .fill(AppColors.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                                .strokeBorder(AppColors.cardStroke, lineWidth: 1)
                        )
                )
            }
        }
    }

    // MARK: - Auto Backup Status

    private var autoBackupSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.standard) {
            SectionHeader(title: "Auto Backup")
            if let error = backupScheduler.lastBackupError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.danger)
                    Text(error)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.danger)
                        .lineLimit(2)
                }
                .padding(.horizontal, AppSpacing.comfortable)
                .padding(.vertical, AppSpacing.standard)
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "externaldrive.fill.badge.checkmark")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.success)
                    Text("Last: \(backupScheduler.lastBackupAgo)")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.inkMuted)
                }
                .padding(.horizontal, AppSpacing.comfortable)
                .padding(.vertical, AppSpacing.standard)
            }
        }
    }

    private func agingColor(days: Int) -> Color {
        if days < memoAgingGreen { return AppColors.success }
        if days < memoAgingYellow { return AppColors.warning }
        if days < memoAgingOrange { return AppColors.warningDeep }
        return AppColors.danger
    }

    private func snapshotChip(_ label: String, _ count: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(AppTypography.largeValue.monospacedDigit())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label.uppercased())
                .font(AppTypography.sectionLabel)
                .foregroundStyle(AppColors.inkSubtle)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.standard)
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                        .strokeBorder(AppColors.cardStroke, lineWidth: 1)
                )
        )
    }
}
