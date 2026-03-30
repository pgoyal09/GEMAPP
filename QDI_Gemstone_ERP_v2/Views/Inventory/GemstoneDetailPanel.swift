import SwiftUI
import SwiftData

/// Detail inspector panel for a selected gemstone.
struct GemstoneDetailPanel: View {
    let gemstone: Gemstone
    var onEdit: (() -> Void)? = nil

    private var isDiamond: Bool { gemstone.stoneType == .diamond }

    var body: some View {
        ScrollView {
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
            .padding(AppSpacing.l)
        }
        .background(AppColors.panelBackground)
    }

    // MARK: - Header

    private var headerCard: some View {
        GlassCard(padding: AppSpacing.m) {
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                HStack {
                    Text(gemstone.sku)
                        .font(AppTypography.mono)
                        .foregroundStyle(AppColors.primary)
                        .padding(.horizontal, AppSpacing.s)
                        .padding(.vertical, AppSpacing.xxs)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(AppColors.primary.opacity(0.12))
                        )

                    Spacer()

                    statusBadge(for: gemstone.status)
                }

                HStack(spacing: AppSpacing.s) {
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
            }
        }
    }

    // MARK: - Sections

    private var overviewSection: some View {
        GlassCard(padding: AppSpacing.m) {
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                SectionHeader(title: "Overview")
                DetailRow(label: "Type", value: gemstone.stoneType.rawValue)
                DetailRow(label: "Shape", value: gemstone.shape.isEmpty ? "--" : gemstone.shape)
                DetailRow(label: "Origin", value: gemstone.origin.isEmpty ? "--" : gemstone.origin)
                DetailRow(label: "Location", value: gemstone.currentLocation)
            }
        }
    }

    private var characteristicsSection: some View {
        GlassCard(padding: AppSpacing.m) {
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                SectionHeader(title: "Characteristics")
                DetailRow(label: "Color", value: gemstone.color.isEmpty ? "--" : gemstone.color)
                DetailRow(label: "Clarity", value: gemstone.clarity.isEmpty ? "--" : gemstone.clarity)
                DetailRow(label: "Cut", value: gemstone.cut.isEmpty ? "--" : gemstone.cut)
                if isDiamond {
                    DetailRow(label: "Polish", value: gemstone.polish.isEmpty ? "--" : gemstone.polish)
                    DetailRow(label: "Symmetry", value: gemstone.symmetry.isEmpty ? "--" : gemstone.symmetry)
                    DetailRow(label: "Fluorescence", value: gemstone.fluorescence.isEmpty ? "--" : gemstone.fluorescence)
                }
            }
        }
    }

    private var dimensionsSection: some View {
        GlassCard(padding: AppSpacing.m) {
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                SectionHeader(title: "Dimensions")
                let l = gemstone.length.map { String(format: "%.2f", $0) } ?? "--"
                let w = gemstone.width.map { String(format: "%.2f", $0) } ?? "--"
                let h = gemstone.height.map { String(format: "%.2f", $0) } ?? "--"
                DetailRow(label: "L x W x H", value: "\(l) x \(w) x \(h) mm")
            }
        }
    }

    private var pricingSection: some View {
        GlassCard(padding: AppSpacing.m) {
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                SectionHeader(title: "Pricing")
                DetailRow(label: "Cost", value: formattedPrice(gemstone.costPrice))
                DetailRow(label: "Sell", value: formattedPrice(gemstone.sellPrice))
            }
        }
    }

    private var rfidSection: some View {
        GlassCard(padding: AppSpacing.m) {
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                SectionHeader(title: "RFID")
                DetailRow(label: "EPC", value: gemstone.rfidEpc ?? "--")
                    .help("Electronic Product Code stored on RFID tags")
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
        }
    }

    private var certificateSection: some View {
        GlassCard(padding: AppSpacing.m) {
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                SectionHeader(title: "Certificate")
                if gemstone.hasCert {
                    DetailRow(label: "Lab", value: gemstone.certLab.isEmpty ? "--" : gemstone.certLab)
                    DetailRow(label: "Number", value: gemstone.certNo.isEmpty ? "--" : gemstone.certNo)
                } else {
                    Text("No certificate")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.inkSubtle)
                }
            }
        }
    }

    // MARK: - History Timeline

    @ViewBuilder
    private var historySection: some View {
        let sortedEvents = gemstone.events.sorted { $0.date > $1.date }
        if !sortedEvents.isEmpty {
            GlassCard(padding: AppSpacing.m) {
                VStack(alignment: .leading, spacing: AppSpacing.s) {
                    SectionHeader(title: "History")
                    ForEach(sortedEvents, id: \.persistentModelID) { event in
                        HStack(alignment: .top, spacing: AppSpacing.s) {
                            Circle()
                                .fill(eventColor(event.eventType))
                                .frame(width: 8, height: 8)
                                .padding(.top, 5)

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
            }
        }
    }

    // MARK: - Helpers

    private func statusBadge(for status: GemstoneStatus) -> StatusBadge {
        switch status {
        case .available: return StatusBadge(title: "Available", tone: .success)
        case .onMemo:    return StatusBadge(title: "On Memo", tone: .warning)
        case .sold:      return StatusBadge(title: "Sold", tone: .accent)
        }
    }

    private func eventColor(_ type: HistoryEventType) -> Color {
        switch type {
        case .dateAdded:            return AppColors.primary
        case .sentToCustomer:       return AppColors.warning
        case .returnedFromCustomer: return AppColors.success
        case .sold:                 return AppColors.accentRose
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
