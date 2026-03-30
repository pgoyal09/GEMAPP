import SwiftUI

struct QuickActionCard: View {
    let title: String
    let icon: String
    let gradient: LinearGradient
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppCornerRadius.m, style: .continuous)
                        .fill(gradient)
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                }
                Text(title)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.inkMuted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: AppCornerRadius.m, style: .continuous)
                    .fill(Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppCornerRadius.m, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

struct QuickActionsGrid: View {
    @Binding var navigateTo: NavigationItem
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    var onAddStone: () -> Void

    var body: some View {
        GlassCard(padding: 20) {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: "Quick Actions")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
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
        }
    }
}
