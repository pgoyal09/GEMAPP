import SwiftUI
import SwiftData
import AppKit

struct GemstoneDetailView: View {
    let stone: Gemstone
    @Environment(\.openWindow) private var openWindow

    private var sortedEvents: [HistoryEvent] {
        stone.events.sorted { $0.date > $1.date }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.l) {
            headerCard
            if stone.effectiveStatus == .onMemo, let memo = stone.memo, let customer = memo.customer {
                Text("On Memo To \(customer.displayName)")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.inkSubtle)
            }
            overviewSection
            characteristicsSection
            dimensionsSection
            pricingSection
            photoSection
            rfidSection
            certificateSection
            mediaSection
            historySection
        }
        .padding(AppSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.background)
    }

    private var headerCard: some View {
        AppSurfaceCard(padding: AppSpacing.m, accent: AppColors.accent) {
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                Text(stone.sku)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.ink)
                HStack(spacing: AppSpacing.s) {
                    if stone.effectiveStatus == .onMemo, let memo = stone.memo {
                        Button {
                            openWindow(id: "memo", value: memo.id)
                        } label: {
                            AppStatusBadge(title: stone.effectiveStatus.rawValue, tone: statusTone)
                        }
                        .buttonStyle(.plain)
                    } else {
                        AppStatusBadge(title: stone.effectiveStatus.rawValue, tone: statusTone)
                    }
                    AppStatusBadge(title: stone.stoneType.rawValue, tone: .accent)
                    Text("\(String(format: "%.2f", stone.caratWeight)) ct")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.inkSubtle)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                if let l = stone.length, let w = stone.width, let h = stone.height {
                    DetailRow(label: "L × W × H", value: "\(formatDim(l)) × \(formatDim(w)) × \(formatDim(h))")
                } else if stone.length != nil || stone.width != nil || stone.height != nil {
                    if let l = stone.length { DetailRow(label: "Length", value: formatDim(l)) }
                    if let w = stone.width { DetailRow(label: "Width", value: formatDim(w)) }
                    if let h = stone.height { DetailRow(label: "Height", value: formatDim(h)) }
                } else {
                    DetailRow(label: "Dimensions", value: "—")
                }
            }
        }
    }

    private var pricingSection: some View {
        detailSection(title: "Pricing") {
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                DetailRow(label: "Cost", value: stone.costPrice.asCurrency)
                DetailRow(label: "Sell", value: stone.sellPrice.asCurrency)
                if let rap = stone.rapPrice {
                    DetailRow(label: "Rap Price", value: rap.asCurrency)
                }
                if let discount = stone.rapDiscount {
                    DetailRow(label: "Rap Discount", value: String(format: "%.1f%%", discount))
                }
                if let ppc = stone.rapPricePerCarat {
                    DetailRow(label: "Rap $/ct", value: ppc.asCurrency)
                }
                if stone.purchaseCurrency != nil && stone.purchaseCurrency != "USD" {
                    if let amt = stone.purchaseAmount {
                        DetailRow(label: "Purchase (\(stone.purchaseCurrency ?? ""))", value: "\(amt)")
                    }
                    if let rate = stone.exchangeRate {
                        DetailRow(label: "Exchange Rate", value: String(format: "%.4f", rate))
                    }
                }
                if let sold = stone.soldPrice {
                    Divider().background(AppColors.cardStroke)
                    DetailRow(label: "Sold Price", value: sold.asCurrency)
                    if let m = stone.margin {
                        DetailRow(label: "Margin", value: m.asCurrency)
                    }
                    if let r = stone.roi {
                        DetailRow(label: "ROI", value: String(format: "%.1f%%", r))
                    }
                    DetailRow(label: "Days Held", value: "\(stone.daysHeld)")
                }
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
                Divider().background(AppColors.cardStroke)
                HStack(spacing: AppSpacing.m) {
                    Text("Tag Printer")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.inkSubtle)
                        .frame(width: 86, alignment: .leading)
                    PrintTagButton(gemstone: stone, style: .pill)
                }
                PrinterConfigView()
            }
        }
    }

    private var photoSection: some View {
        Group {
            if let data = stone.imageData, let nsImage = NSImage(data: data) {
                detailSection(title: "Photo") {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
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
                if let gia = stone.giaReportNumber, !gia.isEmpty {
                    DetailRow(label: "GIA Report #", value: gia)
                }
                if let path = stone.certificateImagePath, !path.isEmpty {
                    DetailRow(label: "Certificate Image", value: (path as NSString).lastPathComponent)
                }
            }
        }
    }

    private var mediaSection: some View {
        Group {
            if !stone.mediaPaths.isEmpty {
                detailSection(title: "Media") {
                    VStack(alignment: .leading, spacing: AppSpacing.s) {
                        ForEach(Array(stone.mediaPaths.enumerated()), id: \.offset) { _, path in
                            DetailRow(label: "File", value: (path as NSString).lastPathComponent)
                        }
                    }
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
                AppSurfaceCard(padding: AppSpacing.m) {
                    Text("No history events")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.inkSubtle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: AppSpacing.s) {
                    ForEach(sortedEvents, id: \.id) { event in
                        HistoryRow(event: event)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func detailSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Text(title)
                .font(AppTypography.heading)
                .foregroundStyle(AppColors.ink)
            AppSurfaceCard(padding: AppSpacing.m) {
                content()
                    .frame(maxWidth: .infinity, minHeight: 52, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formatDim(_ v: Double) -> String {
        String(format: "%.2f", v)
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
                .foregroundStyle(Color.white.opacity(0.70))
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
                    Text(event.eventDescription.isEmpty ? event.eventType.rawValue : event.eventDescription)
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.ink)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
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
