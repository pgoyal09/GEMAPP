import SwiftUI

struct SidebarView: View {
    @Binding var selectedItem: NavigationItem

    var body: some View {
        VStack(spacing: 0) {
            sidebarHeader

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.hero) {
                    ForEach(NavigationItem.groups, id: \.label) { group in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(group.label.uppercased())
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.inkSubtle)
                                .tracking(1.5)
                                .padding(.horizontal, AppSpacing.comfortable)
                                .padding(.bottom, AppSpacing.compact)

                            ForEach(group.items, id: \.self) { item in
                                sidebarRow(item)
                            }
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.comfortable)
                .padding(.vertical, AppSpacing.section)
            }

            Spacer(minLength: 0)

            Button {
                selectedItem = .settings
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "gearshape")
                        .font(AppTypography.body)
                    Text("Settings")
                        .font(AppTypography.smallValue)
                }
                .foregroundStyle(selectedItem == .settings ? AppColors.ink : AppColors.inkSubtle)
                .padding(.horizontal, AppSpacing.section)
                .padding(.vertical, AppSpacing.comfortable)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
            .overlay(alignment: .top) {
                Divider().background(AppColors.cardElevated)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.large, style: .continuous)
                .fill(AppColors.panelBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCornerRadius.large, style: .continuous)
                        .strokeBorder(AppColors.cardStroke, lineWidth: 1)
                )
                .padding(AppSpacing.standard)
        )
    }

    // MARK: - Header

    private var sidebarHeader: some View {
        HStack(spacing: AppSpacing.comfortable) {
            ZStack {
                RoundedRectangle(cornerRadius: AppCornerRadius.medium, style: .continuous)
                    .fill(AppColors.primaryGradient)
                    .frame(width: 36, height: 36)
                    .shadow(color: AppColors.primary.opacity(AppOpacity.muted), radius: 6, y: 2)
                Image(systemName: "diamond.fill")
                    .font(AppTypography.body.weight(.medium))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("QDI Gemstone")
                    .font(AppTypography.body.weight(.medium))
                    .foregroundStyle(AppColors.ink)
                    .tracking(0.3)
                Text("ERP · RFID Studio")
                    .font(AppTypography.sectionLabel)
                    .foregroundStyle(AppColors.inkSubtle)
            }
        }
        .padding(.horizontal, AppSpacing.hero)
        .padding(.top, AppSpacing.hero)
        .padding(.bottom, AppSpacing.section)
        .overlay(alignment: .bottom) {
            Divider().background(AppColors.cardElevated)
        }
    }

    // MARK: - Row

    private func sidebarRow(_ item: NavigationItem) -> some View {
        let isActive = selectedItem == item
        return Button {
            selectedItem = item
        } label: {
            HStack(spacing: 10) {
                Image(systemName: item.icon)
                    .font(AppTypography.body)
                    .frame(width: 16)
                Text(item.rawValue)
                    .font(AppTypography.smallValue)
            }
            .foregroundStyle(isActive ? AppColors.ink : AppColors.inkMuted)
            .padding(.horizontal, AppSpacing.comfortable)
            .padding(.vertical, AppSpacing.standard)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Group {
                    if isActive {
                        RoundedRectangle(cornerRadius: AppCornerRadius.large, style: .continuous)
                            .fill(Color.white.opacity(AppOpacity.subtle))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppCornerRadius.large, style: .continuous)
                                    .strokeBorder(AppColors.cardStroke, lineWidth: 1)
                            )
                    }
                }
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.rawValue)
        .accessibilityIdentifier("sidebar_\(item.rawValue.lowercased().replacingOccurrences(of: " ", with: "_"))")
        .accessibilityAddTraits(isActive ? .isSelected : [])
        .tag(item)
    }
}
