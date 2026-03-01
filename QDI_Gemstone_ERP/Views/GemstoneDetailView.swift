import SwiftUI
import SwiftData

struct GemstoneDetailView: View {
    let stone: Gemstone

    private var sortedEvents: [HistoryEvent] {
        stone.events.sorted { $0.date > $1.date }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.l) {
            headerCard
            overviewSection
            characteristicsSection
            dimensionsSection
            pricingSection
            rfidSection
            certificateSection
            historySection
        }
        .padding(AppSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.background)
    }

    private var headerCard: some View {
        AppSurfaceCard(accent: AppColors.accent) {
            Text(stone.sku)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.ink)
            HStack(spacing: AppSpacing.s) {
                AppStatusBadge(title: stone.effectiveStatus.rawValue, tone: statusTone)
                AppStatusBadge(title: stone.stoneType.rawValue, tone: .accent)
                Text("\(String(format: "%.2f", stone.caratWeight)) ct")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.inkSubtle)
            }
        }
    }

    private var statusTone: AppStatusBadge.Tone {
        switch stone.effectiveStatus {
        case .available: return .success
        case .onMemo: return .warning
        case .sold: return .neutral
        }
    }

    private var overviewSection: some View {
        detailSection(title: "Overview") {
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                DetailRow(label: "SKU", value: stone.sku)
                DetailRow(label: "Type", value: stone.stoneType.rawValue)
                DetailRow(label: "Location", value: stone.currentLocation)
                DetailRow(label: "Origin", value: stone.origin)
            }
        }
    }

    private var characteristicsSection: some View {
        detailSection(title: "Characteristics") {
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                DetailRow(label: "Color", value: stone.color)
                DetailRow(label: "Clarity", value: stone.clarity)
                DetailRow(label: "Cut", value: stone.cut)
            }
        }
    }

    private var dimensionsSection: some View {
        detailSection(title: "Dimensions") {
            let dims: [String] = [stone.length, stone.width, stone.height].compactMap {
                guard let v = $0 else { return nil }
                return formatDim(v)
            }
            if dims.isEmpty {
                DetailRow(label: "Size", value: "Not recorded")
            } else {
                DetailRow(label: "Size", value: dims.joined(separator: " × "))
            }
        }
    }

    private var pricingSection: some View {
        detailSection(title: "Pricing") {
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                DetailRow(label: "Cost", value: formatCurrency(stone.costPrice))
                DetailRow(label: "Sell", value: formatCurrency(stone.sellPrice))
            }
        }
    }

    private var rfidSection: some View {
        detailSection(title: "RFID") {
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                DetailRow(label: "EPC", value: stone.effectiveRfidEpc ?? "Unassigned")
                DetailRow(label: "TID", value: stone.rfidTid ?? "—")
                DetailRow(label: "State", value: stone.rfidStatus ?? "unassigned")
                if let seen = stone.rfidLastSeenAt {
                    DetailRow(label: "Last Seen", value: seen.formatted(date: .abbreviated, time: .shortened))
                }
            }
        }
    }

    private var certificateSection: some View {
        detailSection(title: "Certificate") {
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                DetailRow(label: "Certified", value: (stone.hasCert ?? false) ? "Yes" : "No")
                if let lab = stone.certLab, !lab.isEmpty {
                    DetailRow(label: "Lab", value: lab)
                }
                if let no = stone.certNo, !no.isEmpty {
                    DetailRow(label: "Cert No", value: no)
                }
            }
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            Text("History")
                .font(AppTypography.heading)
                .foregroundStyle(AppColors.ink)
            if sortedEvents.isEmpty {
                AppSurfaceCard {
                    Text("No history events")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.inkSubtle)
                }
            } else {
                VStack(alignment: .leading, spacing: AppSpacing.s) {
                    ForEach(sortedEvents, id: \.id) { event in
                        HistoryRow(event: event)
                    }
                }
            }
        }
    }

    private func detailSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Text(title)
                .font(AppTypography.heading)
                .foregroundStyle(AppColors.ink)
            AppSurfaceCard {
                content()
            }
        }
    }

    private func formatDim(_ v: Double) -> String {
        String(format: "%.2f", v)
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: value as NSDecimalNumber) ?? "$0"
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.m) {
            Text(label)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.inkSubtle)
                .frame(width: 86, alignment: .leading)
            Text(value.isEmpty ? "—" : value)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.ink)
                .lineLimit(2)
                .truncationMode(.tail)
        }
    }
}

struct HistoryRow: View {
    let event: HistoryEvent

    var body: some View {
        AppSurfaceCard(padding: AppSpacing.m) {
            HStack(alignment: .top, spacing: AppSpacing.m) {
                Circle()
                    .fill(AppColors.primary)
                    .frame(width: 8, height: 8)
                    .padding(.top, 6)
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.eventDescription)
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.ink)
                    Text(event.eventType.rawValue)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.inkSubtle)
                    Text(event.date, style: .date)
                        .font(.caption2)
                        .foregroundStyle(AppColors.inkSubtle.opacity(0.8))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
