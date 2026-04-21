import SwiftUI

/// A dismissible getting-started checklist shown on the dashboard after onboarding.
struct GettingStartedChecklist: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDismissed = GettingStartedService.isDismissed
    @State private var completedItems: Set<String> = Set(
        GettingStartedItem.allCases.filter(\.isCompleted).map(\.rawValue)
    )

    /// Incremented by parent to force a re-read of UserDefaults completion state.
    var refreshTrigger: Int = 0

    /// Callback when the user taps a checklist item to navigate.
    var onItemTap: ((GettingStartedItem) -> Void)?

    var body: some View {
        if GettingStartedService.shouldShow && !isDismissed {
            GlassCard(padding: AppSpacing.hero) {
                VStack(alignment: .leading, spacing: AppSpacing.section) {
                    header
                    progressBar
                    itemsList
                }
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
            .accessibilityIdentifier("GettingStartedChecklist")
            .onChange(of: refreshTrigger) { _, _ in
                reloadCompletionState()
            }
        }
    }

    /// Re-read completion state from UserDefaults.
    private func reloadCompletionState() {
        let newSet = Set(GettingStartedItem.allCases.filter(\.isCompleted).map(\.rawValue))
        if newSet != completedItems {
            completedItems = newSet
        }
        isDismissed = GettingStartedService.isDismissed
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: AppSpacing.tight) {
                Text("Getting Started")
                    .font(AppTypography.heading)
                    .foregroundStyle(AppColors.ink)
                Text("\(completedItems.count) of \(GettingStartedItem.allCases.count) complete")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.inkSubtle)
            }
            Spacer()
            Button {
                withAnimation(reduceMotion ? nil : .default) {
                    GettingStartedService.dismiss()
                    isDismissed = true
                }
            } label: {
                Image(systemName: "xmark")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.inkSubtle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss getting started checklist")
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                    .fill(AppColors.cardStroke)
                    .frame(height: 6)
                RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                    .fill(AppColors.primary)
                    .frame(width: geo.size.width * progressFraction, height: 6)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: completedItems.count)
            }
        }
        .frame(height: 6)
        .accessibilityLabel("Progress: \(completedItems.count) of \(GettingStartedItem.allCases.count)")
    }

    private var progressFraction: CGFloat {
        let total = GettingStartedItem.allCases.count
        guard total > 0 else { return 0 }
        return CGFloat(completedItems.count) / CGFloat(total)
    }

    // MARK: - Items

    private var itemsList: some View {
        VStack(spacing: AppSpacing.standard) {
            ForEach(GettingStartedItem.allCases) { item in
                let done = completedItems.contains(item.rawValue)
                Button {
                    onItemTap?(item)
                } label: {
                    HStack(spacing: AppSpacing.comfortable) {
                        Image(systemName: done ? "checkmark.circle.fill" : item.iconName)
                            .font(AppTypography.displaySmallIcon)
                            .foregroundStyle(done ? AppColors.success : AppColors.primary)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: AppSpacing.tight) {
                            Text(item.title)
                                .font(AppTypography.body)
                                .foregroundStyle(done ? AppColors.inkSubtle : AppColors.ink)
                                .strikethrough(done, color: AppColors.inkSubtle)
                            Text(item.subtitle)
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.inkSubtle)
                        }

                        Spacer()

                        if !done {
                            Image(systemName: "chevron.right")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.inkSubtle)
                        }
                    }
                    .padding(.vertical, AppSpacing.compact)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(item.title): \(done ? "completed" : "not completed"). \(item.subtitle)")
                .accessibilityAddTraits(done ? [] : .isButton)
            }
        }
    }
}
