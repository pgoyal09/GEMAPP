import SwiftUI
import SwiftData

struct LotHistorySheet: View {
    let lot: Gemstone
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private var transactions: [LotTransaction] {
        lot.lotTransactions.sorted { $0.date > $1.date }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Lot History")
                        .font(.title2.bold())
                        .foregroundStyle(AppColors.ink)
                    Text("\(lot.sku) · \(lot.stoneType.rawValue)")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.inkMuted)
                }
                Spacer()
                statsView
                Button("Done") { dismiss() }
                    .buttonStyle(GradientButtonStyle())
            }
            .padding(AppSpacing.l)

            Divider().overlay(AppColors.cardStroke)

            HStack(spacing: 0) {
                Text("Type").frame(width: 90, alignment: .leading).padding(.horizontal, 4)
                Text("Date").frame(width: 100, alignment: .leading).padding(.horizontal, 4)
                Text("Carats").frame(width: 80, alignment: .trailing).padding(.horizontal, 4)
                Text("Price/ct").frame(width: 90, alignment: .trailing).padding(.horizontal, 4)
                Text("Total").frame(width: 100, alignment: .trailing).padding(.horizontal, 4)
                Text("Cost/ct").frame(width: 90, alignment: .trailing).padding(.horizontal, 4)
                Text("Profit").frame(width: 100, alignment: .trailing).padding(.horizontal, 4)
                Text("Notes").frame(minWidth: 140, maxWidth: .infinity, alignment: .leading).padding(.horizontal, 4)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppColors.inkSubtle)
            .padding(.horizontal, AppSpacing.l)
            .padding(.vertical, 8)
            .background(AppColors.cardBackground)

            Divider().overlay(AppColors.cardStroke)

            if transactions.isEmpty {
                ContentUnavailableView(
                    "No History",
                    systemImage: "clock",
                    description: Text("No transactions recorded for this lot yet.")
                )
                .foregroundStyle(AppColors.inkMuted)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(transactions) { txn in
                            transactionRow(txn)
                            Divider().overlay(AppColors.cardStroke)
                        }
                    }
                }
            }
        }
        .frame(minWidth: 960, minHeight: 580)
        .background(AppColors.background)
    }

    private var statsView: some View {
        let totalAdded = transactions.filter { $0.type == .added }.reduce(0.0) { $0 + $1.carats }
        let totalSold = transactions.filter { $0.type == .sold }.reduce(0.0) { $0 + $1.carats }
        let totalOnMemo = transactions.filter { $0.type == .onMemo }.reduce(0.0) { $0 + $1.carats }
        let totalReturned = transactions.filter { $0.type == .returned }.reduce(0.0) { $0 + $1.carats }
        let netOnMemo = max(0, totalOnMemo - totalReturned)

        let totalProfit = transactions.compactMap { $0.totalProfit }.reduce(Decimal(0), +)

        return HStack(spacing: AppSpacing.xl) {
            statCell("Total Added", String(format: "%.2f ct", totalAdded), color: AppColors.success)
            statCell("Sold", String(format: "%.2f ct", totalSold), color: AppColors.primary)
            statCell("On Memo", String(format: "%.2f ct", netOnMemo), color: AppColors.warning)
            statCell("Remaining", String(format: "%.2f ct", lot.effectiveRemainingCarats),
                     color: lot.effectiveRemainingCarats <= 0 ? AppColors.danger : AppColors.ink)
            statCell("Total Profit", totalProfit.asCurrency,
                     color: totalProfit >= 0 ? AppColors.success : AppColors.danger)
        }
        .padding(.trailing, AppSpacing.xl)
    }

    private func statCell(_ label: String, _ value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(AppColors.inkMuted)
        }
    }

    @ViewBuilder
    private func transactionRow(_ txn: LotTransaction) -> some View {
        HStack(spacing: 0) {
            typeBadge(txn.type)
                .frame(width: 90, alignment: .leading)
                .padding(.horizontal, 4)
            Text(txn.date, style: .date)
                .font(.body)
                .foregroundStyle(AppColors.ink)
                .frame(width: 100, alignment: .leading)
                .padding(.horizontal, 4)
            Text(String(format: "%.2f", txn.carats))
                .foregroundStyle(AppColors.ink)
                .frame(width: 80, alignment: .trailing)
                .padding(.horizontal, 4)
            Text(txn.pricePerCarat.asCurrency)
                .foregroundStyle(AppColors.ink)
                .frame(width: 90, alignment: .trailing)
                .padding(.horizontal, 4)
            Text(txn.totalPrice.asCurrency)
                .fontWeight(.medium)
                .foregroundStyle(AppColors.ink)
                .frame(width: 100, alignment: .trailing)
                .padding(.horizontal, 4)
            if let cost = txn.lockedCostPerCarat {
                Text(cost.asCurrency)
                    .foregroundStyle(AppColors.ink)
                    .frame(width: 90, alignment: .trailing)
                    .padding(.horizontal, 4)
            } else {
                Text("—")
                    .foregroundStyle(AppColors.inkMuted)
                    .frame(width: 90, alignment: .trailing)
                    .padding(.horizontal, 4)
            }
            if let profit = txn.totalProfit {
                Text(profit.asCurrency)
                    .foregroundStyle(profit >= 0 ? AppColors.success : AppColors.danger)
                    .fontWeight(.medium)
                    .frame(width: 100, alignment: .trailing)
                    .padding(.horizontal, 4)
            } else {
                Text("—")
                    .foregroundStyle(AppColors.inkMuted)
                    .frame(width: 100, alignment: .trailing)
                    .padding(.horizontal, 4)
            }
            Text(txn.notes ?? "")
                .font(.caption)
                .foregroundStyle(AppColors.inkMuted)
                .lineLimit(3)
                .frame(minWidth: 140, maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
        }
        .padding(.horizontal, AppSpacing.l)
        .padding(.vertical, 8)
    }

    private func typeBadge(_ type: LotTransactionType) -> some View {
        let (color, icon): (Color, String) = {
            switch type {
            case .added: return (AppColors.success, "plus.circle.fill")
            case .sold: return (AppColors.primary, "dollarsign.circle.fill")
            case .onMemo: return (AppColors.warning, "doc.text.fill")
            case .returned: return (AppColors.inkMuted, "arrow.uturn.left.circle.fill")
            }
        }()
        return Label(type.rawValue, systemImage: icon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
    }
}
