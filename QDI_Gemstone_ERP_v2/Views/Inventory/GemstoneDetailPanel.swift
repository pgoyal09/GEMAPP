import SwiftUI
import SwiftData

/// Detail inspector panel for a selected gemstone.
struct GemstoneDetailPanel: View {
    let gemstone: Gemstone
    var onEdit: (() -> Void)? = nil
    @Environment(\.openWindow) private var openWindow
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDirty = false
    @State private var showDiscardAlert = false

    private var isDiamond: Bool { gemstone.stoneType == .diamond }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                headerSection
                sectionDivider
                identitySection
                sectionDivider
                measurementsSection
                if isDiamond {
                    sectionDivider
                    characteristicsSection
                }
                sectionDivider
                certificationSection
                sectionDivider
                pricingSection
                sectionDivider
                rfidSection
                historySection
            }
            .padding(.vertical, AppSpacing.comfortable)
        }
        .id(gemstone.persistentModelID)
        .background(AppColors.panelBackground)
        .accessibilityIdentifier("GemstoneDetailPanel")
    }

    // MARK: - Section Divider

    private var sectionDivider: some View {
        Divider()
            .background(AppColors.cardStroke.opacity(0.5))
            .padding(.horizontal, AppSpacing.section)
            .padding(.vertical, AppSpacing.comfortable)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.comfortable) {
            HStack {
                Text(gemstone.sku)
                    .font(AppTypography.mono)
                    .foregroundStyle(AppColors.primary)
                Spacer()
                statusBadge(for: gemstone.status)
            }

            HStack(spacing: AppSpacing.comfortable) {
                StoneTypeBadge(type: gemstone.stoneType.rawValue)
                Text(String(format: "%.2f ct", gemstone.caratWeight))
                    .font(AppTypography.largeValue)
                    .foregroundStyle(AppColors.ink)
            }

            if let onEdit {
                Button {
                    onEdit()
                } label: {
                    Label("Edit Stone", systemImage: "pencil")
                }
                .buttonStyle(.outline)
                .frame(maxWidth: .infinity)
            }

            if let memo = gemstone.memo {
                Button {
                    openWindow(id: "memo", value: memo.persistentModelID)
                } label: {
                    Label("View Memo", systemImage: "arrow.right.circle")
                }
                .buttonStyle(.outline(AppColors.warning))
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, AppSpacing.section)
    }

    // MARK: - Two-Column Grid

    private var twoColumnLayout: [GridItem] {
        [GridItem(.flexible(), spacing: AppSpacing.comfortable), GridItem(.flexible(), spacing: AppSpacing.comfortable)]
    }

    // MARK: - Identity

    private var identitySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.comfortable) {
            SectionHeader(title: "Identity")
            LazyVGrid(columns: twoColumnLayout, alignment: .leading, spacing: AppSpacing.comfortable) {
                DetailRow(label: "Stock #", value: gemstone.sku)
                DetailRow(label: "Type", value: gemstone.stoneType.rawValue)
                DetailRow(label: "Shape", value: gemstone.shape.isEmpty ? "--" : gemstone.shape)
                DetailRow(label: "Carat Wt", value: String(format: "%.2f ct", gemstone.caratWeight))
                DetailRow(label: "Color", value: gemstone.color.isEmpty ? "--" : gemstone.color)
                DetailRow(label: "Clarity", value: gemstone.clarity.isEmpty ? "--" : gemstone.clarity)
                DetailRow(label: "Cut Grade", value: gemstone.cut.isEmpty ? "--" : gemstone.cut)
                DetailRow(label: "Origin", value: gemstone.origin.isEmpty ? "--" : gemstone.origin)
                if !isDiamond {
                    DetailRow(label: "Treatment", value: gemstone.treatment.isEmpty ? "None" : gemstone.treatment)
                }
                DetailRow(label: "Location", value: gemstone.currentLocation)
            }
        }
        .padding(.horizontal, AppSpacing.section)
    }

    // MARK: - Measurements

    private var measurementsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.comfortable) {
            SectionHeader(title: "Measurements")
            let l = gemstone.length.map { String(format: "%.2f", $0) } ?? "--"
            let w = gemstone.width.map { String(format: "%.2f", $0) } ?? "--"
            let h = gemstone.height.map { String(format: "%.2f", $0) } ?? "--"
            LazyVGrid(columns: twoColumnLayout, alignment: .leading, spacing: AppSpacing.comfortable) {
                DetailRow(label: "Length", value: "\(l) mm")
                DetailRow(label: "Width", value: "\(w) mm")
                DetailRow(label: "Depth", value: "\(h) mm")
                DetailRow(label: "Table %", value: gemstone.tablePct.map { String(format: "%.1f%%", $0) } ?? "--")
                DetailRow(label: "Depth %", value: gemstone.depthPct.map { String(format: "%.1f%%", $0) } ?? "--")
            }
        }
        .padding(.horizontal, AppSpacing.section)
    }

    // MARK: - Characteristics (Diamond-specific)

    private var characteristicsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.comfortable) {
            SectionHeader(title: "Characteristics")
            LazyVGrid(columns: twoColumnLayout, alignment: .leading, spacing: AppSpacing.comfortable) {
                DetailRow(label: "Polish", value: gemstone.polish.isEmpty ? "--" : gemstone.polish)
                DetailRow(label: "Symmetry", value: gemstone.symmetry.isEmpty ? "--" : gemstone.symmetry)
                DetailRow(label: "Fluorescence", value: gemstone.fluorescence.isEmpty ? "--" : gemstone.fluorescence)
            }
        }
        .padding(.horizontal, AppSpacing.section)
    }

    // MARK: - Certification

    private var certificationSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.comfortable) {
            SectionHeader(title: "Certification")
            if gemstone.hasCert {
                LazyVGrid(columns: twoColumnLayout, alignment: .leading, spacing: AppSpacing.comfortable) {
                    DetailRow(label: "Lab", value: gemstone.certLab.isEmpty ? "--" : gemstone.certLab)
                    DetailRow(label: "Cert #", value: gemstone.certNo.isEmpty ? "--" : gemstone.certNo)
                }
            } else {
                Text("No certificate")
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.inkSubtle)
            }
        }
        .padding(.horizontal, AppSpacing.section)
    }

    // MARK: - Pricing

    private var pricingSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.comfortable) {
            SectionHeader(title: "Pricing")
            LazyVGrid(columns: twoColumnLayout, alignment: .leading, spacing: AppSpacing.comfortable) {
                DetailRow(label: "Cost", value: formattedPrice(gemstone.costPrice))
                DetailRow(label: "Price/ct", value: gemstone.caratWeight > 0
                    ? formattedPrice(gemstone.sellPrice)
                    : "--")
                DetailRow(label: "Total Price", value: formattedPrice(gemstone.sellPrice * Decimal(gemstone.caratWeight)))
            }
        }
        .padding(.horizontal, AppSpacing.section)
    }

    // MARK: - RFID

    private var rfidSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.comfortable) {
            SectionHeader(title: "RFID")
            DetailRow(label: "EPC", value: gemstone.rfidEpc ?? "--")
            DetailRow(label: "TID", value: gemstone.rfidTid ?? "--")
            if let assignedAt = gemstone.rfidAssignedAt {
                DetailRow(label: "Assigned", value: formattedDate(assignedAt))
            }
            if let lastSeen = gemstone.rfidLastSeenAt {
                DetailRow(label: "Last Seen", value: formattedDate(lastSeen))
            }
            if gemstone.rfidEpc != nil {
                StatusBadge(title: "Tagged", tone: .success)
            } else {
                StatusBadge(title: "Not Tagged", tone: .neutral)
            }
        }
        .padding(.horizontal, AppSpacing.section)
    }

    // MARK: - History Timeline

    @ViewBuilder
    private var historySection: some View {
        let sortedEvents = gemstone.events.sorted { $0.date > $1.date }
        if !sortedEvents.isEmpty {
            sectionDivider
            VStack(alignment: .leading, spacing: AppSpacing.comfortable) {
                SectionHeader(title: "History")
                ForEach(sortedEvents, id: \.persistentModelID) { event in
                    HStack(alignment: .top, spacing: AppSpacing.comfortable) {
                        Circle()
                            .fill(eventColor(event.eventType))
                            .frame(width: 8, height: 8)
                            .padding(.top, AppSpacing.compact)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.eventDescription)
                                .font(AppTypography.body)
                                .foregroundStyle(AppColors.ink)
                            Text(formattedDate(event.date))
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.inkSubtle)
                        }
                    }
                    if event.persistentModelID != sortedEvents.last?.persistentModelID {
                        Rectangle()
                            .fill(AppColors.cardStroke)
                            .frame(width: 1, height: 12)
                            .padding(.leading, 3.5)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.section)
        }
    }

    // MARK: - Helpers

    private func statusBadge(for status: GemstoneStatus) -> StatusBadge {
        switch status {
        case .available:    return StatusBadge(title: "Available", tone: .success)
        case .onMemo:       return StatusBadge(title: "On Memo", tone: .warning)
        case .sold:         return StatusBadge(title: "Sold", tone: .accent)
        case .atLab:        return StatusBadge(title: "At Lab", tone: .accent)
        case .reserved:     return StatusBadge(title: "Reserved", tone: .warning)
        case .inTransit:    return StatusBadge(title: "In Transit", tone: .accent)
        case .consignment:  return StatusBadge(title: "Consignment", tone: .neutral)
        }
    }

    private func eventColor(_ type: HistoryEventType) -> Color {
        switch type {
        case .dateAdded:            return AppColors.primary
        case .sentToCustomer:       return AppColors.warning
        case .returnedFromCustomer: return AppColors.success
        case .sold:                 return AppColors.accentRose
        case .priceUpdated:         return AppColors.inkMuted
        }
    }

    private func formattedPrice(_ price: Decimal) -> String {
        price.asCurrency
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
