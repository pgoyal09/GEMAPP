import SwiftUI
import SwiftData

// MARK: - DashboardView Section Extensions

extension DashboardView {

    var rfidStatusPill: some View {
        GlassCard(padding: 14, cornerRadius: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    AppStatusBadge(title: rfidManager.connectionStatus.rawValue, tone: rfidTone)
                    Spacer()
                    Button("Reconnect") { rfidManager.reconnect() }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppColors.primary)
                        .buttonStyle(.plain)
                }
                if let err = rfidManager.lastErrorMessage {
                    Text(err)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.white.opacity(0.30))
                        .lineLimit(2)
                }
                if rfidManager.connectionStatus == .scanning {
                    HStack(spacing: 8) {
                        Text("Unique: \(rfidManager.uniqueTagsThisSession)")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.white.opacity(0.40))
                        if let tag = rfidManager.lastScannedTag {
                            Text(truncatedHex(tag))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(Color.white.opacity(0.30))
                                .lineLimit(1)
                        }
                    }
                    HStack(spacing: 8) {
                        Button(rfidManager.isScanningPaused ? "Resume" : "Pause") {
                            rfidManager.isScanningPaused ? rfidManager.resumeScanning() : rfidManager.pauseScanning()
                        }
                        .font(.system(size: 11))
                        .foregroundStyle(AppColors.primary)
                        .buttonStyle(.plain)
                        Button("Reset Session") { rfidManager.resetScanSession() }
                            .font(.system(size: 11))
                            .foregroundStyle(Color.white.opacity(0.40))
                            .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    var rfidTone: AppStatusBadge.Tone {
        switch rfidManager.connectionStatus {
        case .disconnected: return .neutral
        case .connecting, .initializing: return .warning
        case .connected, .scanning: return .success
        case .error: return .danger
        }
    }

    func truncatedHex(_ s: String) -> String {
        guard s.count > 24 else { return s }
        return String(s.prefix(12)) + "…" + String(s.suffix(8))
    }

    var oldestOpenMemosSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("OLDEST OPEN MEMOS")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.30))
                .tracking(1.5)
            if viewModel.oldestOpenMemos.isEmpty {
                Text("No open memos")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.30))
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(viewModel.oldestOpenMemos) { item in
                        memoRowButton(item: item)
                    }
                }
            }
        }
    }

    func memoRowButton(item: OldestMemoItem) -> some View {
        Button {
            openWindow(id: "memo", value: item.id)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("#\(item.referenceNumber ?? "—")")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.80))
                    Text(item.customerName)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.40))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(item.ageDays)d")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.30))
                    Text(item.totalAmount.asCurrency)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.50))
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .contentShape(Rectangle())
            .background(
                selectedMemoID == item.id
                    ? RoundedRectangle(cornerRadius: 8).fill(AppColors.primary.opacity(0.08))
                    : nil
            )
        }
        .buttonStyle(.plain)
    }

    func memoDetailSummary(item: OldestMemoItem) -> some View {
        GlassCard(padding: 14, cornerRadius: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Memo #\(item.referenceNumber ?? "—")")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.80))
                Text("Customer: \(item.customerName)")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.50))
                Text("Total: \(item.totalAmount.asCurrency)")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.50))
                Text("Status: \(item.status.rawValue)")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.30))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    var inventorySnapshotSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("INVENTORY SNAPSHOT")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.30))
                .tracking(1.5)
            HStack(spacing: 10) {
                snapshotChip("Available", viewModel.inventorySnapshot.availableCount, color: AppColors.success)
                snapshotChip("On Memo", viewModel.inventorySnapshot.onMemoCount, color: AppColors.primary)
                snapshotChip("Sold", viewModel.inventorySnapshot.soldCount, color: Color.white.opacity(0.60))
            }
        }
    }

    func snapshotChip(_ label: String, _ count: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(Color.white.opacity(0.25))
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
                )
        )
    }

    var recentActivitySection: some View {
        GlassCard(padding: 20) {
            VStack(alignment: .leading, spacing: 16) {
                Text("RECENT ACTIVITY")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.50))
                    .tracking(1.5)
                if viewModel.recentActivity.isEmpty {
                    Text("No recent activity")
                        .foregroundStyle(Color.white.opacity(0.30))
                        .font(.system(size: 13))
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    VStack(spacing: 0) {
                        ForEach(viewModel.recentActivity) { activity in
                            Button {
                                openWindow(id: "memo", value: activity.id)
                            } label: {
                                HStack {
                                    Text(activity.title)
                                        .font(.system(size: 13))
                                        .foregroundStyle(Color.white.opacity(0.60))
                                        .lineLimit(1)
                                    Spacer()
                                }
                                .padding(.vertical, 12)
                                .overlay(alignment: .bottom) {
                                    Divider().background(Color.white.opacity(0.04))
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    var resetDataSection: some View {
        Button {
            showResetConfirm = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.clockwise.circle")
                    .font(.system(size: 13))
                Text("Generate New Mock Data")
                    .font(.system(size: 13))
            }
            .foregroundStyle(Color.white.opacity(0.40))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isResetting)
    }
}
