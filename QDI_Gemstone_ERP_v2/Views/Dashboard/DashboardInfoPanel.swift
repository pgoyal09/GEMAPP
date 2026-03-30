import SwiftUI

struct DashboardInfoPanel: View {
    let viewModel: DashboardViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.l) {
                oldestOpenMemosSection
                inventorySnapshotSection
            }
            .padding(AppSpacing.l)
        }
        .frame(width: 296)
        .background(Color.white.opacity(0.02))
        .overlay(alignment: .leading) {
            Divider().background(Color.white.opacity(0.06))
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
                        .foregroundStyle(Color.orange)
                    Text("\(viewModel.overdueMemoCount) memo\(viewModel.overdueMemoCount == 1 ? "" : "s") over 60 days")
                        .font(AppTypography.caption)
                        .foregroundStyle(Color.orange)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.orange.opacity(0.12))
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
                snapshotChip("Sold", viewModel.inventorySnapshot.soldCount, color: AppColors.inkMuted)
            }
        }
    }

    private func agingColor(days: Int) -> Color {
        switch days {
        case ..<30: return AppColors.success
        case 30..<60: return AppColors.warning
        case 60..<90: return Color.orange
        default: return AppColors.danger
        }
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
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: AppCornerRadius.m, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
                )
        )
    }
}
