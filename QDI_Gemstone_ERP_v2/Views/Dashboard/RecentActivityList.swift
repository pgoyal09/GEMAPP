import SwiftUI

struct RecentActivityList: View {
    let items: [RecentActivityItem]
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        GlassCard(padding: 20) {
            VStack(alignment: .leading, spacing: 16) {
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
                                openWindow(id: "memo", value: item.id)
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: item.icon)
                                        .font(.system(size: 12))
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
                                .padding(.vertical, 10)
                                .overlay(alignment: .bottom) {
                                    Divider().background(AppColors.panelBackground)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}
