import SwiftUI

struct QuickActionCard: View {
    let title: String
    let icon: String
    let gradient: LinearGradient
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: AppSpacing.standard) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                        .fill(gradient)
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(AppTypography.body.weight(.medium))
                        .foregroundStyle(.white)
                }
                Text(title)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.inkMuted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(AppSpacing.comfortable)
            .background(
                RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                    .fill(AppColors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                            .strokeBorder(isHovered ? AppColors.primary : AppColors.cardStroke, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in isHovered = hovering }
        .accessibilityLabel(title)
    }
}

struct QuickActionsGrid: View {
    @Binding var navigateTo: NavigationItem
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    var onAddStone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.section) {
            SectionHeader(title: "Quick Actions")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: AppSpacing.comfortable), count: 4), spacing: AppSpacing.comfortable) {
                QuickActionCard(title: "Add Stone", icon: "diamond.fill", gradient: AppColors.primaryGradient, action: onAddStone)
                QuickActionCard(title: "Quick Intake", icon: "plus.circle.fill", gradient: AppColors.emeraldGradient) {
                    navigateTo = .quickIntake
                }
                QuickActionCard(title: "Review Queue", icon: "list.bullet.clipboard", gradient: AppColors.violetGradient) {
                    navigateTo = .reviewQueue
                }
                QuickActionCard(title: "New Memo", icon: "doc.text.fill", gradient: AppColors.amberGradient) {
                    do {
                        let memo = try TransactionService.createMemo(modelContext: modelContext)
                        openWindow(id: "memo", value: memo.persistentModelID)
                    } catch {
                        AppLogger.ui.error("Failed to create memo: \(error.localizedDescription)")
                    }
                }
                QuickActionCard(title: "New Invoice", icon: "doc.richtext.fill", gradient: AppColors.roseGradient) {
                    do {
                        let inv = try TransactionService.createInvoice(modelContext: modelContext)
                        openWindow(id: "invoice", value: inv.persistentModelID)
                    } catch {
                        AppLogger.ui.error("Failed to create invoice: \(error.localizedDescription)")
                    }
                }
                QuickActionCard(title: "Diamonds", icon: "sparkle", gradient: AppColors.primaryGradient) {
                    navigateTo = .diamonds
                }
                QuickActionCard(title: "Customers", icon: "person.2.fill", gradient: AppColors.violetGradient) {
                    navigateTo = .customers
                }
                QuickActionCard(title: "Scanner", icon: "antenna.radiowaves.left.and.right",
                                gradient: LinearGradient(colors: [.gray, Color(white: 0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)) {
                    navigateTo = .scanner
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
