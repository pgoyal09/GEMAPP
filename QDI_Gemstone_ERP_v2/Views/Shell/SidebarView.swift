import SwiftUI

struct SidebarView: View {
    @Binding var selectedItem: NavigationItem

    var body: some View {
        VStack(spacing: 0) {
            sidebarHeader

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(NavigationItem.groups, id: \.label) { group in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(group.label.uppercased())
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.inkSubtle)
                                .tracking(1.5)
                                .padding(.horizontal, 12)
                                .padding(.bottom, 4)

                            ForEach(group.items, id: \.self) { item in
                                sidebarRow(item)
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 16)
            }

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                Image(systemName: "gearshape")
                    .font(AppTypography.body)
                Text("Settings")
                    .font(AppTypography.smallValue)
            }
            .foregroundStyle(AppColors.inkSubtle)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .top) {
                Divider().background(Color.white.opacity(0.06))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.l, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: AppCornerRadius.l, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
                .padding(8)
        )
    }

    // MARK: - Header

    private var sidebarHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(AppColors.primaryGradient)
                    .frame(width: 36, height: 36)
                    .shadow(color: AppColors.primary.opacity(0.20), radius: 6, y: 2)
                Image(systemName: "diamond.fill")
                    .font(.system(size: 16, weight: .medium))
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
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
        .overlay(alignment: .bottom) {
            Divider().background(Color.white.opacity(0.06))
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
            .foregroundStyle(isActive ? Color.white : AppColors.inkMuted)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Group {
                    if isActive {
                        RoundedRectangle(cornerRadius: AppCornerRadius.m, style: .continuous)
                            .fill(Color.white.opacity(0.10))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppCornerRadius.m, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    }
                }
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .tag(item)
    }
}
