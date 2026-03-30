import SwiftUI

struct DashboardInfoPanel: View {
    let viewModel: DashboardViewModel
    @Environment(\.openWindow) private var openWindow
    @AppStorage("memoAgingGreen") private var memoAgingGreen: Int = 7
    @AppStorage("memoAgingYellow") private var memoAgingYellow: Int = 14
    @AppStorage("memoAgingOrange") private var memoAgingOrange: Int = 30

    private var backupScheduler = BackupScheduler()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.l) {
                oldestOpenMemosSection
                inventorySnapshotSection
                if backupScheduler.isEnabled {
                    autoBackupSection
                }
            }
            .padding(AppSpacing.l)
        }
        .frame(width: 296)
        .background(AppColors.panelBackground)
        .overlay(alignment: .leading) {
            Divider().background(AppColors.cardElevated)
        }
    }

    // MARK: - Oldest Open Memos

    private var oldestOpenMemosSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.compact) {
            SectionHeader(title: "Oldest Open Memos")
            if viewModel.overdueMemoCount > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(AppColors.warningDeep)
                    Text("\(viewModel.overdueMemoCount) memo\(viewModel.overdueMemoCount == 1 ? "" : "s") over 60 days")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.warningDeep)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: AppCornerRadius.sm, style: .continuous)
                        .fill(AppColors.warningDeep.opacity(0.12))
                )
            }
            if viewModel.oldestOpenMemos.isEmpty {
                Text("No open memos")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.inkSubtle)
                    .padding(.vertical, AppSpacing.compact)
            } else {
                VStack(spacing: 0) {
                    ForEach(viewModel.oldestOpenMemos) { item in
                        Button {
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
                            .padding(.vertical, AppSpacing.compact)
                            .padding(.horizontal, AppSpacing.s)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Inventory Snapshot

    private var inventorySnapshotSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.compact) {
            SectionHeader(title: "Inventory Snapshot")
            HStack(spacing: 10) {
                snapshotChip("Available", viewModel.inventorySnapshot.availableCount, color: AppColors.success)
                snapshotChip("On Memo", viewModel.inventorySnapshot.onMemoCount, color: AppColors.primary)
                    .help("Consignment agreement allowing customer to review stones before buying")
                snapshotChip("Sold", viewModel.inventorySnapshot.soldCount, color: AppColors.inkMuted)
            }
        }
    }

    // MARK: - Auto Backup Status

    private var autoBackupSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.compact) {
            SectionHeader(title: "Auto Backup")
            HStack(spacing: 6) {
                Image(systemName: "externaldrive.fill.badge.checkmark")
                    .font(.system(size: 11))
                    .foregroundStyle(AppColors.success)
                Text("Last: \(backupScheduler.lastBackupAgo)")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.inkMuted)
            }
            .padding(.horizontal, AppSpacing.s)
            .padding(.vertical, AppSpacing.compact)
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
            Text(label.uppercased())
                .font(.system(size: 10))
                .foregroundStyle(AppColors.inkSubtle)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.m, style: .continuous)
                .fill(AppColors.panelBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCornerRadius.m, style: .continuous)
                        .strokeBorder(AppColors.cardStroke, lineWidth: 1)
                )
        )
    }
}
