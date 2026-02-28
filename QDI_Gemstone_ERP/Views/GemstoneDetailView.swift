import SwiftUI
import SwiftData

struct GemstoneDetailView: View {
    let stone: Gemstone

    private var sortedEvents: [HistoryEvent] {
        stone.events.sorted { $0.date > $1.date }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xl) {
            overviewSection
            characteristicsSection
            pricingSection
            certificateSection
            historySection
        }
        .padding(AppSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var overviewSection: some View {
        detailSection(title: "Overview") {
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                DetailRow(label: "SKU", value: stone.sku)
                DetailRow(label: "Type", value: stone.stoneType.rawValue)
                DetailRow(label: "Status", value: stone.effectiveStatus.rawValue)
                DetailRow(label: "Location", value: stone.currentLocation)
                DetailRow(label: "Carat", value: String(format: "%.2f", stone.caratWeight))
            }
        }
    }

    private var characteristicsSection: some View {
        detailSection(title: "Characteristics") {
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                DetailRow(label: "Color", value: stone.color)
                DetailRow(label: "Clarity", value: stone.clarity)
                DetailRow(label: "Cut", value: stone.cut)
                DetailRow(label: "Origin", value: stone.origin)
                if let l = stone.length, let w = stone.width, let h = stone.height {
                    DetailRow(label: "Dimensions", value: "\(formatDim(l)) × \(formatDim(w)) × \(formatDim(h))")
                }
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
                .font(.headline)
                .foregroundStyle(.secondary)
            if sortedEvents.isEmpty {
                Text("No history events")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .padding(AppSpacing.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            content()
                .padding(AppSpacing.l)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.controlBackgroundColor))
                .cornerRadius(AppCornerRadius.m)
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
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value.isEmpty ? "—" : value)
                .font(.subheadline)
                .lineLimit(2)
                .truncationMode(.tail)
        }
    }
}

struct HistoryRow: View {
    let event: HistoryEvent

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.m) {
            Circle()
                .fill(AppColors.primary)
                .frame(width: 8, height: 8)
                .padding(.top, 6)
            VStack(alignment: .leading, spacing: 4) {
                Text(event.eventDescription)
                    .font(.subheadline)
                Text(event.eventType.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(event.date, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(AppSpacing.m)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(AppCornerRadius.s)
    }
}
