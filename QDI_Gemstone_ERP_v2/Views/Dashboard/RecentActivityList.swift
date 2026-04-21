import SwiftUI

struct RecentActivityList: View {
    let items: [RecentActivityItem]
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openDocumentTracker) private var openDocTracker

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.section) {
            SectionHeader(title: "Recent Activity")
            if items.isEmpty {
                Text("No recent activity")
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.inkSubtle)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 0) {
                    ForEach(items) { item in
                        Button {
                            guard !openDocTracker.isOpen(memoID: item.id) else { return }
                            openWindow(id: "memo", value: item.id)
                        } label: {
                            HStack(spacing: AppSpacing.standard) {
                                Image(systemName: item.icon)
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.primary)
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .font(AppTypography.body)
                                        .foregroundStyle(AppColors.inkMuted)
                                    Text(item.subtitle)
                                        .font(AppTypography.caption)
                                        .foregroundStyle(AppColors.inkSubtle)
                                }
                                Spacer()
                                Text(item.date.relativeTimeString)
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.inkSubtle)
                            }
                            .frame(height: 32)
                            .padding(.horizontal, AppSpacing.comfortable)
                            .overlay(alignment: .bottom) {
                                Divider().background(AppColors.cardStroke)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(item.title), \(item.subtitle), \(item.date.relativeTimeString)")
                    }
                }
            }
        }
        .padding(AppSpacing.hero)
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
